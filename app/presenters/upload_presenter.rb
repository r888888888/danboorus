class UploadPresenter < Presenter
  def initialize(upload)
    @upload = upload
  end

  def status(template)
    case @upload.status
    when /duplicate: (\d+)/
      dup_post_id = $1
      template.link_to(@upload.status.gsub(/error: RuntimeError - /, ""), template.__send__(:booru_post_path, Booru.current, dup_post_id))

    else
      @upload.status
    end
  end
end
