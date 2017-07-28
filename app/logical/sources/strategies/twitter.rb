module Sources::Strategies
  class Twitter < Base
    def self.url_match?(url)
      url =~ %r!https?://(?:mobile\.)?twitter\.com/\w+/status/\d+! || url =~ %r{https?://pbs\.twimg\.com/media/}
    end

    def referer_url
      if @referer_url =~ %r!https?://(?:mobile\.)?twitter\.com/\w+/status/\d+! && @url =~ %r{https?://pbs\.twimg\.com/media/}
        @referer_url
      else
        @url
      end
    end

    def site_name
      "Twitter"
    end

    def api_response
      status_id = status_id_from_url(url)
      @api_response ||= TwitterService.new.client.status(status_id)
    end

    def get
      attrs = api_response.attrs
      @artist_name = attrs[:user][:name]
      @profile_url = "https://twitter.com/" + attrs[:user][:screen_name]
      @image_url = image_urls.first
      @tags = attrs[:entities][:hashtags].map do |text:, indices:|
        [text, "https://twitter.com/hashtag/#{text}"]
      end
    rescue ::Twitter::Error::Forbidden
    end

    def image_urls
      TwitterService.new.image_urls(url)
    end

    def status_id_from_url(url)
      if url =~ %r{^https?://(?:mobile\.)?twitter\.com/\w+/status/(\d+)}
        $1.to_i
      else
        raise Sources::Error.new("Couldn't get status ID from URL: #{url}")
      end
    end
  end
end
