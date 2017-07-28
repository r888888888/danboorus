require 'test_helper'

module Sources
  class PawooTest < ActiveSupport::TestCase
    context "The source site for a https://pawoo.net/web/status/$id url"  do
      setup do
        @site = Sources::Site.new("https://pawoo.net/web/statuses/1202176")
        @site.get
      end

      should "get the profile" do
        assert_equal("https://pawoo.net/@9ed00e924818", @site.profile_url)
      end

      should "get the artist name" do
        assert_equal("9ed00e924818", @site.artist_name)
      end

      should "get the image url" do
        assert_equal("https://img.pawoo.net/media_attachments/files/000/128/953/original/4c0a06087b03343f.png", @site.image_url)
      end
    end

    context "The source site for a https://pawoo.net/$user/$id url"  do
      setup do
        @site = Sources::Site.new("https://pawoo.net/@evazion/19451018")
        @site.get
      end

      should "get the profile" do
        assert_equal("https://pawoo.net/@evazion", @site.profile_url)
      end

      should "get the artist name" do
        assert_equal("evazion", @site.artist_name)
      end

      should "get the image urls" do
        urls = %w[
          https://img.pawoo.net/media_attachments/files/001/297/997/original/c4272a09570757c2.png
          https://img.pawoo.net/media_attachments/files/001/298/028/original/55a6fd252778454b.mp4
          https://img.pawoo.net/media_attachments/files/001/298/081/original/2588ee9ba808f38f.webm
          https://img.pawoo.net/media_attachments/files/001/298/084/original/media.mp4
        ]

        assert_equal(urls, @site.image_urls)
      end

      should "get the tags" do
        assert_equal(%w[baz bar foo], @site.tags.map(&:first))
      end
    end

    context "The source site for a https://img.pawoo.net/ url"  do
      setup do
        @url = "https://img.pawoo.net/media_attachments/files/001/298/028/original/55a6fd252778454b.mp4"
        @ref = "https://pawoo.net/@evazion/19451018"
        @site = Sources::Site.new(@url, referer_url: @ref)
        @site.get
      end

      should "fetch the source data" do
        assert_equal("evazion", @site.artist_name)
      end
    end
  end
end
