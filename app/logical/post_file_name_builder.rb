module PostFileNameBuilder
  def file_path_prefix
    Rails.env.test? ? "test-" : ""
  end

  def data_home_dir
    ENV["DANBOORU_DATA_HOME_DIR"]
  end

  def file_path
    "#{data_home_dir}/original/#{file_name}"
  end

  def file_name
    "#{file_path_prefix}#{sha256}.#{file_ext}"
  end

  def resized_file_path_for(width)
    case width
    when Danbooru.config.small_image_width
      "#{data_home_dir}/preview/#{file_path_prefix}#{sha256}.jpg"

    when Danbooru.config.large_image_width
      "#{data_home_dir}/sample/#{file_path_prefix}#{sha256}.#{large_file_ext}"
    end
  end

  def has_large?
    return true if is_ugoira?
    is_image? && image_width.present? && image_width > Danbooru.config.large_image_width
  end

  def large_file_path
    if has_large?
      "#{data_home_dir}/sample/#{file_path_prefix}#{sha256}.#{large_file_ext}"
    else
      file_path
    end
  end

  def preview_file_path
    "#{data_home_dir}/preview/#{file_path_prefix}#{sha256}.jpg"
  end

  def file_url
    "/data/original/#{file_path_prefix}#{sha256}.#{file_ext}"
  end

  def s3_file_url
    "https://#{s3_domain}/#{Danbooru.config.aws_s3_bucket_name}/original/#{file_path_prefix}#{sha256}.#{file_ext}"
  end

  def large_file_url
    if has_large?
      "data/sample/#{file_path_prefix}#{sha256}.#{large_file_ext}"
    else
      file_url
    end
  end

  def s3_domain
    "s3-us-west-1.amazonaws.com"
  end

  def s3_large_file_url
    "https://#{s3_domain}/#{Danbooru.config.aws_s3_bucket_name}/large/#{file_path_prefix}#{sha256}.#{large_file_ext}"
  end

  def preview_file_url
    if !has_preview?
      return "images/download-preview.png"
    end

    "/data/preview/#{file_path_prefix}#{sha256}.jpg"
  end

  def s3_preview_file_url
    if !has_preview?
      return "https://#{s3_domain}/#{Danbooru.config.aws_s3_bucket_name}/preview/download-preview.png"
    end

    "https://#{s3_domain}/#{Danbooru.config.aws_s3_bucket_name}/preview/#{file_path_prefix}#{sha256}.jpg"
  end

  def large_file_ext
    if is_ugoira?
      "webm"
    else
      "jpg"
    end
  end

  def temp_file_path
    @temp_file_path ||= Tempfile.new("upload").path
  end
end
