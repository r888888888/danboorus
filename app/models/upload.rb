require "danbooru_image_resizer/danbooru_image_resizer"
require "tmpdir"

class Upload < ApplicationRecord
  class Error < Exception ; end

  attr_accessor :file, :image_width, :image_height, :file_ext, :md5, 
    :file_size, :as_pending,
    :referer_url, :downloaded_source
  belongs_to :uploader, :class_name => "User"
  belongs_to :post
  before_validation :initialize_uploader, :on => :create
  before_validation :initialize_status, :on => :create
  validate :uploader_is_not_limited, :on => :create
  validate :file_or_source_is_present, :on => :create
  validate :rating_given
  attr_accessible :file, :image_width, :image_height, :file_ext, :md5, 
    :file_size, :as_pending, :source, :file_path, :content_type, :rating, 
    :tag_string, :status, :backtrace, :post_id, :md5_confirmation, 
    :parent_id, :server,
    :referer_url

  module ValidationMethods
    def uploader_is_not_limited
      if !uploader.can_upload?
        self.errors.add(:uploader, uploader.upload_limited_reason)
        return false
      else
        return true
      end
    end

    def file_or_source_is_present
      if file.blank? && source.blank?
        self.errors.add(:base, "Must choose file or specify source")
        return false
      else
        return true
      end
    end

    # Because uploads are processed serially, there's no race condition here.
    def validate_md5_uniqueness
      md5_post = Post.find_by_md5(md5)
      if md5_post
        raise "duplicate: #{md5_post.id}"
      end
    end

    def validate_file_exists(path)
      unless path && File.exists?(path)
        raise "file does not exist"
      end
    end

    def validate_file_content_type
      unless is_valid_content_type?
        raise "invalid content type (only JPEG, PNG, GIF, SWF, MP4, and WebM files are allowed)"
      end

      if is_ugoira? && ugoira_service.empty?
        raise "missing frame data for ugoira"
      end
    end

    def validate_md5_confirmation
      if !md5_confirmation.blank? && md5_confirmation != md5
        raise "md5 mismatch"
      end
    end

    def validate_md5_confirmation_after_move(path)
      if !md5_confirmation.blank? && md5_confirmation != Digest::MD5.file(path).hexdigest
        raise "md5 mismatch"
      end
    end

    def rating_given
      if rating.present?
        return true
      elsif tag_string =~ /(?:\s|^)rating:([se])/i
        self.rating = $1.downcase
        return true
      else
        self.errors.add(:base, "Must specify a rating")
        return false
      end
    end

    def tag_audio
      if is_video? && video.audio_channels.present?
        self.tag_string = "#{tag_string} video_with_sound"
      end
    end

    def validate_video_duration
      if is_video? && video.duration > 120
        raise "video must not be longer than 2 minutes"
      end
    end
  end

  module ConversionMethods
    def process_upload
      CurrentUser.scoped(uploader, uploader_ip_addr) do
        update_attribute(:status, "processing")
        Tempfile.create("upload") do |file|
          temp_path = file.path
          convert_cgi_file(temp_path)
          self.source = strip_source
          if is_downloadable?
            self.downloaded_source, self.source = download_from_source(temp_path)
          end
          validate_file_exists(temp_path)
          self.content_type = file_header_to_content_type(temp_path)
          self.file_ext = content_type_to_file_ext(content_type)
          validate_file_content_type
          calculate_hash(temp_path)
          validate_md5_uniqueness
          validate_md5_confirmation
          tag_audio
          validate_video_duration
          calculate_file_size(temp_path)
          if has_dimensions?
            calculate_dimensions(temp_path)
          end
          generate_resizes(temp_path)
          move_file(temp_path)
          validate_md5_confirmation_after_move(file_path)
        end
        save
      end
    end

    def create_post_from_upload
      post = convert_to_post
      post.distribute_files
      if post.save
        User.where(id: CurrentUser.id).update_all("post_upload_count = post_upload_count + 1")
        ugoira_service.save_frame_data(post) if is_ugoira?
        update_attributes(:status => "completed", :post_id => post.id)
      else
        update_attribute(:status, "error: " + post.errors.full_messages.join(", "))
      end
    end

    def process!(force = false)
      @tries ||= 0
      return if !force && status =~ /processing|completed|error/

      process_upload
      create_post_from_upload

    rescue Timeout::Error, Net::HTTP::Persistent::Error => x
      if @tries > 3
        update_attributes(:status => "error: #{x.class} - #{x.message}", :backtrace => x.backtrace.join("\n"))
      else
        @tries += 1
        retry
      end

    rescue Exception => x
      update_attributes(:status => "error: #{x.class} - #{x.message}", :backtrace => x.backtrace.join("\n"))
    end

    def async_conversion?
      is_ugoira?
    end

    def ugoira_service
      @ugoira_service ||= PixivUgoiraService.new
    end

    def convert_to_post
      Post.new.tap do |p|
        p.tag_string = tag_string
        p.md5 = md5
        p.file_ext = file_ext
        p.image_width = image_width
        p.image_height = image_height
        p.rating = rating
        p.source = source
        p.file_size = file_size
        p.uploader_id = uploader_id
        p.uploader_ip_addr = uploader_ip_addr
        p.parent_id = parent_id
      end
    end
  end

  module FileMethods
    def move_file(path)
      return if File.exists?(file_path)
      FileUtils.cp(path, file_path)
    end

    def calculate_file_size(path)
      self.file_size = File.size(path)
    end

    # Calculates the MD5 based on whatever is in
    def calculate_hash(path)
      self.md5 = Digest::MD5.file(path).hexdigest
    end

    def is_image?
      %w(jpg gif png).include?(file_ext)
    end

    def is_flash?
      %w(swf).include?(file_ext)
    end

    def is_video?
      %w(webm mp4).include?(file_ext)
    end

    def is_ugoira?
      %w(zip).include?(file_ext)
    end
  end

  module ResizerMethods
    def generate_resizes(path)
      generate_resize_for(Danbooru.config.small_image_width, Danbooru.config.small_image_width, path, preview_file_path, 85)

      if is_image? && image_width > Danbooru.config.large_image_width
        generate_resize_for(Danbooru.config.large_image_width, nil, path, large_file_path)
      end
    end

    def generate_video_preview_for(width, height, dest_path)
      dimension_ratio = image_width.to_f / image_height
      if dimension_ratio > 1
        height = (width / dimension_ratio).to_i
      else
        width = (height * dimension_ratio).to_i
      end
      video.screenshot(dest_path, {:seek_time => 0, :resolution => "#{width}x#{height}"})
      FileUtils.chmod(0664, dest_path)
    end

    def generate_resize_for(width, height, source_path, dest_path, quality = 90)
      unless File.exists?(source_path)
        raise Error.new("file not found")
      end

      if is_image?
        Danbooru.resize(source_path, dest_path, width, height, quality)
      elsif is_ugoira?
        if Delayed::Worker.delay_jobs
          # by the time this runs we'll have moved source_path to file_path
          ugoira_service.generate_resizes(file_path, resized_file_path_for(Danbooru.config.large_image_width), dest_path)
        else
          ugoira_service.generate_resizes(source_path, resized_file_path_for(Danbooru.config.large_image_width), dest_path, false)
        end
      elsif is_video?
        generate_video_preview_for(width, height, dest_path)
      end
    end
  end

  module DimensionMethods
    # Figures out the dimensions of the image.
    def calculate_dimensions(path)
      if is_video?
        self.image_width = video.width
        self.image_height = video.height
      elsif is_ugoira?
        ugoira_service.calculate_dimensions(path)
        self.image_width = ugoira_service.width
        self.image_height = ugoira_service.height
      else
        File.open(path, "rb") do |file|
          image_size = ImageSpec.new(file)
          self.image_width = image_size.width
          self.image_height = image_size.height
        end
      end
    end

    # Does this file have image dimensions?
    def has_dimensions?
      %w(jpg gif png swf webm mp4 zip).include?(file_ext)
    end
  end

  module ContentTypeMethods
    def is_valid_content_type?
      file_ext =~ /jpg|gif|png|swf|webm|mp4|zip/
    end

    def content_type_to_file_ext(content_type)
      case content_type
      when "image/jpeg"
        "jpg"

      when "image/gif"
        "gif"

      when "image/png"
        "png"

      when "application/x-shockwave-flash"
        "swf"

      when "video/webm"
        "webm"

      when "video/mp4"
        "mp4"

      when "application/zip"
        "zip"

      else
        "bin"
      end
    end

    def file_header_to_content_type(path)
      case File.read(path, 16)
      when /^\xff\xd8/n
        "image/jpeg"

      when /^GIF87a/, /^GIF89a/
        "image/gif"

      when /^\x89PNG\r\n\x1a\n/n
        "image/png"

      when /^CWS/, /^FWS/, /^ZWS/
        "application/x-shockwave-flash"

      when /^\x1a\x45\xdf\xa3/n
        "video/webm"

      when /^....ftyp(?:isom|3gp5|mp42|MSNV|avc1)/
        "video/mp4"

      when /^PK\x03\x04/
        "application/zip"

      else
        "application/octet-stream"
      end
    end
  end

  module DownloaderMethods
    def strip_source
      source.to_s.strip
    end

    # Determines whether the source is downloadable
    def is_downloadable?
      source =~ /^https?:\/\// && file.blank?
    end

    # Downloads the file
    def download_from_source(path)
      download = Downloads::File.new(source, path, :referer_url => referer_url)
      download.download!
      ugoira_service.load(download.data)
      [download.downloaded_source, download.source]
    end
  end

  module CgiFileMethods
    def convert_cgi_file(path)
      return if file.blank? || file.size == 0

      if file.respond_to?(:tempfile) && file.tempfile
        FileUtils.cp(file.tempfile.path, path)
      else
        File.open(path, 'wb') do |out|
          out.write(file.read)
        end
      end
      FileUtils.chmod(0664, path)
    end
  end

  module StatusMethods
    def initialize_status
      self.status = "pending"
    end

    def is_pending?
      status == "pending"
    end

    def is_processing?
      status == "processing"
    end

    def is_completed?
      status == "completed"
    end

    def is_duplicate?
      status =~ /duplicate/
    end

    def duplicate_post_id
      @duplicate_post_id ||= status[/duplicate: (\d+)/, 1]
    end
  end

  module UploaderMethods
    def initialize_uploader
      self.uploader_id = CurrentUser.user.id
      self.uploader_ip_addr = CurrentUser.ip_addr
    end

    def uploader_name
      User.id_to_name(uploader_id)
    end
  end

  module VideoMethods
    def video
      @video ||= FFMPEG::Movie.new(file_path)
    end
  end

  module SearchMethods
    def uploaded_by(user_id)
      where("uploader_id = ?", user_id)
    end

    def pending
      where(:status => "pending")
    end

    def search(params)
      q = where("true")
      return q if params.blank?

      if params[:uploader_id].present?
        q = q.uploaded_by(params[:uploader_id].to_i)
      end

      if params[:uploader_name].present?
        q = q.where("uploader_id = (select _.id from users _ where lower(_.name) = ?)", params[:uploader_name].mb_chars.downcase)
      end

      if params[:source].present?
        q = q.where("source = ?", params[:source])
      end

      q
    end
  end

  module ApiMethods
    def method_attributes
      super + [:uploader_name]
    end
  end

  include PostFileNameBuilder
  include ConversionMethods
  include ValidationMethods
  include FileMethods
  include ResizerMethods
  include DimensionMethods
  include ContentTypeMethods
  include DownloaderMethods
  include CgiFileMethods
  include StatusMethods
  include UploaderMethods
  include VideoMethods
  extend SearchMethods
  include ApiMethods

  def presenter
    @presenter ||= UploadPresenter.new(self)
  end

  def upload_as_pending?
    as_pending == "1"
  end
end
