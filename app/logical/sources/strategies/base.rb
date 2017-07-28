# This is a collection of strategies for extracting information about a 
# resource. At a minimum it tries to extract the artist name and a canonical 
# URL to download the image from. But it can also be used to normalize a URL 
# for use with the artist finder. It differs from Downloads::RewriteStrategies
# in that the latter is more for normalizing and rewriting a URL until it is 
# suitable for downloading, whereas Sources::Strategies is more for meta-data 
# that can only be obtained by downloading and parsing the resource.

module Sources
  module Strategies
    class Base
      attr_reader :url, :referer_url
      attr_reader :artist_name, :profile_url, :image_url, :tags

      def self.url_match?(url)
        false
      end

      def initialize(url, referer_url = nil)
        @url = url
        @referer_url = referer_url
      end

      # No remote calls are made until this method is called.
      def get
        raise NotImplementedError
      end

      def get_size
        @get_size ||= Downloads::File.new(@image_url).size
      end

      def site_name
        raise NotImplementedError
      end

      def unique_id
        artist_name
      end

      def image_urls
        [image_url]
      end

      def tags
        (@tags || []).uniq
      end

      def translated_tags
        translated_tags = tags.map(&:first).flat_map(&method(:translate_tag)).uniq.sort
        translated_tags.map { |tag| [tag.name, tag.category] }
      end

      # Given a tag from the source site, should return an array of corresponding Danbooru tags.
      def translate_tag(untranslated_tag)
        translated_tags = Tag.where(name: WikiPage.active.other_names_equal([untranslated_tag]).uniq.select(:title))

        if translated_tags.empty?
          normalized_name = [Tag.normalize_name(untranslated_tag)]
          translated_tags = Tag.nonempty.where(name: normalized_name)
        end

        translated_tags
      end

      # Should be set to a url for sites that prevent hotlinking, or left nil for sites that don't.
      def fake_referer
        nil
      end

    protected
      def agent
        raise NotImplementedError
      end
    end
  end
end
