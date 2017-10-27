class S3BackupService < BackupService
  attr_reader :client, :bucket

  def initialize(client: nil, bucket: Danbooru.config.aws_s3_bucket_name)
    @credentials = Aws::Credentials.new(Danbooru.config.aws_access_key_id, Danbooru.config.aws_secret_access_key)
    @client = client || Aws::S3::Client.new(credentials: @credentials, region: "us-east-1", logger: Logger.new(STDOUT))
    @bucket = bucket
  end

  def backup(file_path, type: nil, **options)
    key = s3_key(file_path, type)
    upload_to_s3(key, file_path)
  end

  def delete(file_path, type: nil)
    key = s3_key(file_path, type)
    delete_from_s3(key)
  end

protected
  def s3_key(file_path, type)
    case type
    when :original
      "original/#{File.basename(file_path)}"
    when :preview
      "preview/#{File.basename(file_path)}"
    when :large
      "sample/#{File.basename(file_path)}"
    else
      raise ArgumentError.new("Unknown type: #{type}")
    end
  end

  def delete_from_s3(key)
    client.delete_object(bucket: bucket, key: key)
  rescue Aws::S3::Errors::NoSuchKey
    # ignore
  end

  def upload_to_s3(key, file_path)
    File.open(file_path, "rb") do |body|
      base64_md5 = Digest::MD5.file(file_path).base64digest
      client.put_object(acl: "public-read", bucket: bucket, key: key, body: body, content_md5: base64_md5)
    end
  end
end
