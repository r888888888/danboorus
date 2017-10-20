require 'fileutils'

FactoryGirl.define do
  factory(:upload) do
    rating "s"
    uploader :factory => :user, :level => 20
    uploader_ip_addr "127.0.0.1"
    tag_string "special"
    status "pending"
    server Socket.gethostname
    source "xxx"
    content_type "image/jpeg"

    factory(:source_upload) do
      source "http://www.google.com/intl/en_ALL/images/logo.gif"
    end

    factory(:jpg_upload) do
      sha256 Base64.urlsafe_encode64 Digest::SHA256.file("#{Rails.root}/test/files/test.jpg").digest
      file_ext "jpg"
      file do
        f = Tempfile.new
        f.write(File.read("#{Rails.root}/test/files/test.jpg"))
        f.seek(0)
        f
      end

      after(:create) do |rec|
        FileUtils.cp("#{Rails.root}/test/files/test.jpg", "#{Rails.root}/public/data/original/test-#{rec.sha256}.jpg")
      end
    end

    factory(:exif_jpg_upload) do
      sha256 Base64.urlsafe_encode64 Digest::SHA256.file("#{Rails.root}/test/files/test-exif-small.jpg").digest
      file_ext "jpg"
      after(:create) do |rec|
        FileUtils.cp("#{Rails.root}/test/files/test-exif-small.jpg", "#{Rails.root}/public/data/original/test-#{rec.sha256}.jpg")
      end
    end

    factory(:blank_jpg_upload) do
      sha256 Base64.urlsafe_encode64 Digest::SHA256.file("#{Rails.root}/test/files/test-blank.jpg").digest
      file_ext "jpg"
      after(:create) do |rec|
        FileUtils.cp("#{Rails.root}/test/files/test-blank.jpg", "#{Rails.root}/public/data/original/test-#{rec.sha256}.jpg")
      end
    end

    factory(:large_jpg_upload) do
      file_ext "jpg"
      sha256 Base64.urlsafe_encode64 Digest::SHA256.file("#{Rails.root}/test/files/test-large.jpg").digest
      after(:create) do |rec|
        FileUtils.cp("#{Rails.root}/test/files/test-large.jpg", "#{Rails.root}/public/data/original/test-#{rec.sha256}.jpg")
      end
    end

    factory(:png_upload) do
      sha256 Base64.urlsafe_encode64 Digest::SHA256.file("#{Rails.root}/test/files/test.png").digest
      file_ext "png"
      content_type "image/png"
      after(:create) do |rec|
        FileUtils.cp("#{Rails.root}/test/files/test.png", "#{Rails.root}/public/data/original/test-#{rec.sha256}.png")
      end
    end

    factory(:gif_upload) do
      sha256 Base64.urlsafe_encode64 Digest::SHA256.file("#{Rails.root}/test/files/test.gif").digest
      content_type "image/gif"
      file_ext "gif"
      after(:create) do |rec|
        FileUtils.cp("#{Rails.root}/test/files/test.gif", "#{Rails.root}/public/data/original/test-#{rec.sha256}.gif")
      end
    end

    factory(:swf_upload) do
      sha256 Base64.urlsafe_encode64 Digest::SHA256.file("#{Rails.root}/test/files/compressed.swf").digest
      file_ext "swf"
      after(:create) do |rec|
        FileUtils.cp("#{Rails.root}/test/files/compressed.swf", "#{Rails.root}/public/data/original/test-#{rec.sha256}.swf")
      end
    end
  end
end

