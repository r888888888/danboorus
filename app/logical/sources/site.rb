# encoding: UTF-8

module Sources
  class Site
    attr_reader :url, :strategy
    delegate :get, :get_size, :site_name, :artist_name, 
      :profile_url, :image_url, :tags, :unique_id, 
      :file_url, :ugoira_frame_data, :ugoira_content_type, :image_urls,
      :rewrite_thumbnails, :illust_id_from_url, :translate_tag, :translated_tags, :to => :strategy

    def self.strategies
      [Strategies::PixivWhitecube, Strategies::Pixiv, Strategies::NicoSeiga, Strategies::DeviantArt, Strategies::ArtStation, Strategies::Nijie, Strategies::Twitter, Strategies::Tumblr, Strategies::Pawoo]
    end

    def initialize(url, referer_url: nil)
      @url = url

      Site.strategies.each do |strategy|
        if strategy.url_match?(url) || strategy.url_match?(referer_url)
          @strategy = strategy.new(url, referer_url)
          break
        end
      end
    end

    def referer_url
      strategy.try(:referer_url)
    end

    def to_h
      return {
        :artist_name => artist_name,
        :profile_url => profile_url,
        :image_url => image_url,
        :image_urls => image_urls,
        :tags => tags,
        :translated_tags => translated_tags,
        :unique_id => unique_id
      }
    end

    def to_json
      to_h.to_json
    end

    def available?
      strategy.present?
    end
  end
end
