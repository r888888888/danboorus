require 'test_helper'

module Sources
  class TumblrTest < ActiveSupport::TestCase
    context "The source for a 'http://*.tumblr.com/post/*' photo post with a single image" do
      setup do
        @site = Sources::Site.new("https://noizave.tumblr.com/post/162206271767")
        @site.get
      end

      should "get the artist name" do
        assert_equal("noizave", @site.artist_name)
      end

      should "get the profile" do
        assert_equal("https://noizave.tumblr.com/", @site.profile_url)
      end

      should "get the tags" do
        tags = [["tag", "https://tumblr.com/tagged/tag"], ["red_hair", "https://tumblr.com/tagged/red-hair"]]
        assert_equal(tags, @site.tags)
      end

      should "get the image url" do
        assert_equal("http://data.tumblr.com/3bbfcbf075ddf969c996641b264086fd/tumblr_os2buiIOt51wsfqepo1_raw.png", @site.image_url)
      end
    end

    context "The source for a 'http://*.tumblr.com/image/*' image page" do
      setup do
        @site = Sources::Site.new("https://noizave.tumblr.com/image/162206271767")
        @site.get
      end

      should "get the image url" do
        assert_equal("http://data.tumblr.com/3bbfcbf075ddf969c996641b264086fd/tumblr_os2buiIOt51wsfqepo1_raw.png", @site.image_url)
      end

      should "get the tags" do
        tags = [["tag", "https://tumblr.com/tagged/tag"], ["red_hair", "https://tumblr.com/tagged/red-hair"]]
        assert_equal(tags, @site.tags)
      end
    end

    context "The source for a 'http://*.media.tumblr.com/$hash/tumblr_$id_1280.jpg' image with a referer" do
      setup do
        @url = "https://68.media.tumblr.com/7c4d2c6843466f92c3dd0516e749ec35/tumblr_orwwptNBCE1wsfqepo2_1280.jpg"
        @ref = "https://noizave.tumblr.com/post/162094447052"
        @site = Sources::Site.new(@url, referer_url: @ref)
        @site.get
      end

      should "get the image urls" do
        urls = %w[
          http://data.tumblr.com/afed9f5b3c33c39dc8c967e262955de2/tumblr_orwwptNBCE1wsfqepo1_raw.png
          http://data.tumblr.com/7c4d2c6843466f92c3dd0516e749ec35/tumblr_orwwptNBCE1wsfqepo2_raw.jpg
          http://data.tumblr.com/d2ed224f135b0c81f812df81a0a8692d/tumblr_orwwptNBCE1wsfqepo3_raw.gif
          http://data.tumblr.com/3bbfcbf075ddf969c996641b264086fd/tumblr_inline_os3134mABB1v11u29_raw.png
          http://data.tumblr.com/34ed9d0ff4a21625981372291cb53040/tumblr_nv3hwpsZQY1uft51jo1_raw.gif
        ]

        assert_equal(urls, @site.image_urls)
      end

      should "get the tags" do
        tags = [["tag1", "https://tumblr.com/tagged/tag1"], ["tag2", "https://tumblr.com/tagged/tag2"]]
        assert_equal(tags, @site.tags)
      end
    end

    context "The source for a 'http://*.tumblr.com/post/*' text post with inline images" do
      setup do
        @site = Sources::Site.new("https://noizave.tumblr.com/post/162221502947")
        @site.get
      end

      should "get the image urls" do
        urls = %w[
          http://data.tumblr.com/afed9f5b3c33c39dc8c967e262955de2/tumblr_inline_os2zhkfhY01v11u29_raw.png
          http://data.tumblr.com/7c4d2c6843466f92c3dd0516e749ec35/tumblr_inline_os2zkg02xH1v11u29_raw.jpg
        ]

        assert_equal(urls, @site.image_urls)
      end
    end

    context "The source for a 'http://*.tumblr.com/post/*' video post with inline images" do
      setup do
        @site = Sources::Site.new("https://noizave.tumblr.com/post/162222617101")
        @site.get
      end

      should "get the image urls" do
        urls = %w[
          https://vtt.tumblr.com/tumblr_os31dkexhK1wsfqep.mp4
          http://data.tumblr.com/afed9f5b3c33c39dc8c967e262955de2/tumblr_inline_os31dclyCR1v11u29_raw.png
        ]

        assert_equal(urls, @site.image_urls)
      end
    end
  end
end
