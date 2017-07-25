module Downloads
  class File
    class Error < Exception ; end

    attr_reader :data, :options
    attr_accessor :source, :original_source, :downloaded_source, :content_type, :file_path

    def initialize(source, file_path, options = {})
      # source can potentially get rewritten in the course
      # of downloading a file, so check it again
      @source = source
      @original_source = source

      # the URL actually downloaded after rewriting the original source.
      @downloaded_source = nil

      # where to save the download
      @file_path = file_path

      # we sometimes need to capture data from the source page
      @data = {}

      @options = options

      @data[:get_thumbnail] = options[:get_thumbnail]
    end

    def size
      @source, headers, @data = before_download(@source, @data)
      options = { timeout: 3, headers: headers }.deep_merge(Danbooru.config.httparty_options)
      res = HTTParty.head(@source, options)
      res.content_length
    end

    def download!
      ::File.open(@file_path, "wb") do |out|
        @source, @data = http_get_streaming(@source, @data) do |response|
          out.write(response)
        end
      end
      @downloaded_source = @source
      @source = after_download(@source)
    end

    def before_download(url, datums)
      headers = Danbooru.config.http_headers

      RewriteStrategies::Base.strategies.each do |strategy|
        url, headers, datums = strategy.new(url).rewrite(url, headers, datums)
      end

      return [url, headers, datums]
    end

    def after_download(src)
      src = fix_twitter_sources(src)
      if options[:referer_url].present?
        src = set_source_to_referer(src, options[:referer_url])
      end
      src
    end

    def validate_local_hosts(url)
      ip_addr = IPAddr.new(Resolv.getaddress(url.hostname))
      if Danbooru.config.banned_ip_for_download?(ip_addr)
        raise Error.new("Banned server for download")
      end
    end

    def http_get_streaming(src, datums = {}, options = {}, &block)
      max_size = options[:max_size]
      max_size = nil if max_size == 0 # unlimited
      limit = 4
      tries = 0
      url = URI.parse(src)

      while true
        unless url.is_a?(URI::HTTP) || url.is_a?(URI::HTTPS)
          raise Error.new("URL must be HTTP or HTTPS")
        end

        src, headers, datums = before_download(src, datums)
        url = URI.parse(src)

        validate_local_hosts(url)

        begin
          options = { stream_body: true, timeout: 10, headers: headers }
          res = HTTParty.get(url, options.deep_merge(Danbooru.config.httparty_options), &block)

          if res.success?
            if max_size
              len = res["Content-Length"]
              raise Error.new("File is too large (#{len} bytes)") if len && len.to_i > max_size
            end

            @content_type = res["Content-Type"]

            return [src, datums]
          else
            raise Error.new("HTTP error code: #{res.code} #{res.message}")
          end
        rescue Errno::ECONNRESET, Errno::ETIMEDOUT, Errno::EIO, Errno::EHOSTUNREACH, Errno::ECONNREFUSED, IOError => x
          tries += 1
          if tries < 3
            retry
          else
            raise
          end
        end
      end # while

      [src, datums]
    end # def

    def fix_twitter_sources(src)
      if src =~ %r!^https?://pbs\.twimg\.com/! && original_source =~ %r!^https?://twitter\.com/!
        original_source
      elsif src =~ %r!^https?://img\.pawoo\.net/! && original_source =~ %r!^https?://pawoo\.net/!
        original_source
      else
        src
      end
    end

    def set_source_to_referer(src, referer)
      if Sources::Strategies::Nijie.url_match?(src) ||
         Sources::Strategies::Twitter.url_match?(src) ||
         Sources::Strategies::Pawoo.url_match?(src) ||
         Sources::Strategies::Tumblr.url_match?(src) || Sources::Strategies::Tumblr.url_match?(referer)
         Sources::Strategies::ArtStation.url_match?(src) || Sources::Strategies::ArtStation.url_match?(referer)
        strategy = Sources::Site.new(src, :referer_url => referer)
        strategy.referer_url
      else
        src
      end
    end
  end
end
