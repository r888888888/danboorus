class PostReplacement < ApplicationRecord
  DELETION_GRACE_PERIOD = 30.days

  belongs_to :post
  belongs_to :creator, class_name: "User"
  before_validation :initialize_fields
  attr_accessor :replacement_file, :final_source, :tags

  def initialize_fields
    self.creator = CurrentUser.user
    self.original_url = post.source
    self.tags = post.tag_string + " " + self.tags.to_s
  end

  def undo!
    undo_replacement = post.replacements.create(replacement_url: original_url)
    undo_replacement.process!
  end

  def process!
    transaction do
      upload = Upload.create!(file: replacement_file, source: replacement_url, rating: post.rating, tag_string: self.tags)
      upload.process_upload
      upload.update(status: "completed", post_id: post.id)

      if replacement_file.present?
        update(replacement_url: "file://#{replacement_file.original_filename}")
      else
        update(replacement_url: upload.downloaded_source)
      end

      # queue the deletion *before* updating the post so that we use the old
      # md5/file_ext to delete the old files. if saving the post fails,
      # this is rolled back so the job won't run.
      Post.delay(queue: "default", run_at: Time.now + DELETION_GRACE_PERIOD).delete_files(post.id, post.file_path, post.large_file_path, post.preview_file_path)

      post.md5 = upload.md5
      post.file_ext = upload.file_ext
      post.image_width = upload.image_width
      post.image_height = upload.image_height
      post.file_size = upload.file_size
      post.source = final_source.presence || upload.source
      post.tag_string = upload.tag_string
      rescale_notes
      update_ugoira_frame_data(upload)

      post.comments.create!({creator: User.system, body: comment_replacement_message, do_not_bump_post: true}, without_protection: true)
      ModAction.log(modaction_replacement_message)

      post.save!
    end

    # point of no return: these things can't be rolled back, so we do them
    # only after the transaction successfully commits.
    post.distribute_files
  end

  def rescale_notes
    x_scale = post.image_width.to_f  / post.image_width_was.to_f
    y_scale = post.image_height.to_f / post.image_height_was.to_f

    post.notes.each do |note|
      note.rescale!(x_scale, y_scale)
    end
  end

  def update_ugoira_frame_data(upload)
    post.pixiv_ugoira_frame_data.destroy if post.pixiv_ugoira_frame_data.present?
    upload.ugoira_service.save_frame_data(post) if post.is_ugoira?
  end

  module SearchMethods
    def post_tags_match(query)
      PostQueryBuilder.new(query).build(self.joins(:post))
    end

    def search(params = {})
      q = all

      if params[:creator_id].present?
        q = q.where(creator_id: params[:creator_id].split(",").map(&:to_i))
      end

      if params[:creator_name].present?
        q = q.where(creator_id: User.name_to_id(params[:creator_name]))
      end

      if params[:id].present?
        q = q.where(id: params[:id].split(",").map(&:to_i))
      end

      if params[:post_id].present?
        q = q.where(post_id: params[:post_id].split(",").map(&:to_i))
      end

      if params[:post_tags_match].present?
        q = q.post_tags_match(params[:post_tags_match])
      end

      q = q.order("created_at DESC")

      q
    end
  end

  module PresenterMethods
    def comment_replacement_message
      %("#{creator.name}":[/users/#{creator.id}] replaced this post with a new image:\n\n#{replacement_message})
    end

    def modaction_replacement_message
      "replaced post ##{post.id}:\n\n#{replacement_message}"
    end

    def replacement_message
      linked_source = linked_source(replacement_url)
      linked_source_was = linked_source(post.source_was)

      <<-EOS.strip_heredoc
        [table]
          [tbody]
            [tr]
              [th]Old[/th]
              [td]#{linked_source_was}[/td]
              [td]#{post.md5_was}[/td]
              [td]#{post.file_ext_was}[/td]
              [td]#{post.image_width_was} x #{post.image_height_was}[/td]
              [td]#{post.file_size_was.to_s(:human_size, precision: 4)}[/td]
            [/tr]
            [tr]
              [th]New[/th]
              [td]#{linked_source}[/td]
              [td]#{post.md5}[/td]
              [td]#{post.file_ext}[/td]
              [td]#{post.image_width} x #{post.image_height}[/td]
              [td]#{post.file_size.to_s(:human_size, precision: 4)}[/td]
            [/tr]
          [/tbody]
        [/table]
      EOS
    end

    def linked_source(source)
      # truncate long sources in the middle: "www.pixiv.net...lust_id=23264933"
      truncated_source = source.gsub(%r{\Ahttps?://}, "").truncate(64, omission: "...#{source.last(32)}")

      if source =~ %r{\Ahttps?://}i
        %("#{truncated_source}":[#{source}])
      else
        truncated_source
      end
    end

    def suggested_tags_for_removal
      tags = post.tag_array.select { |tag| Danbooru.config.remove_tag_after_replacement?(tag) }
      tags = tags.map { |tag| "-#{tag}" }
      tags.join(" ")
    end
  end

  include PresenterMethods
  extend SearchMethods
end
