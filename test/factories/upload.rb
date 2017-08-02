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
      md5 "ecef68c44edb8a0d6a3070b5f8e8ee76"
      file_ext "jpg"
      file do
        f = Tempfile.new
        f.write(File.read("#{Rails.root}/test/files/test.jpg"))
        f.seek(0)
        f
      end

      after(:create) do
        FileUtils.cp("#{Rails.root}/test/files/test.jpg", "#{Rails.root}/public/data/original/test-ecef68c44edb8a0d6a3070b5f8e8ee76.jpg")
      end
    end

    factory(:exif_jpg_upload) do
      md5 "ed46f3279411f2979cc24c991e2bc75f"
      file_ext "jpg"
      after(:create) do
        FileUtils.cp("#{Rails.root}/test/files/test-exif-small.jpg", "#{Rails.root}/public/data/original/test-ed46f3279411f2979cc24c991e2bc75f.jpg")
      end
    end

    factory(:blank_jpg_upload) do
      md5 "674c66d7b7b901cfa6dd87d9bd01a17a"
      file_ext "jpg"
      after(:create) do
        FileUtils.cp("#{Rails.root}/test/files/test-blank.jpg", "#{Rails.root}/public/data/original/test-674c66d7b7b901cfa6dd87d9bd01a17a.jpg")
      end
    end

    factory(:large_jpg_upload) do
      file_ext "jpg"
      md5 "8e147f02611a9286870a97c726338e62"
      after(:create) do
        FileUtils.cp("#{Rails.root}/test/files/test-large.jpg", "#{Rails.root}/public/data/original/test-8e147f02611a9286870a97c726338e62.jpg")
      end
    end

    factory(:png_upload) do
      md5 "081a5c3b92d8980d1aadbd215bfac5b9"
      file_ext "png"
      content_type "image/png"
      after(:create) do
        FileUtils.cp("#{Rails.root}/test/files/test.png", "#{Rails.root}/public/data/original/test-081a5c3b92d8980d1aadbd215bfac5b9.png")
      end
    end

    factory(:gif_upload) do
      md5 "1e2edf6bdbd971d8c3cc4da0f98f38ab"
      content_type "image/gif"
      file_ext "gif"
      after(:create) do
        FileUtils.cp("#{Rails.root}/test/files/test.gif", "#{Rails.root}/public/data/original/test-1e2edf6bdbd971d8c3cc4da0f98f38ab.gif")
      end
    end
  end
end

