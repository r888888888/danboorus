require 'test_helper'

module Sources
  class DeviantArtTest < ActiveSupport::TestCase
    context "The source for an DeviantArt artwork page" do
      setup do
        @site = Sources::Site.new("http://noizave.deviantart.com/art/test-post-please-ignore-685436408")
        @site.get
      end

      should "get the image url" do
        assert_equal("http://orig02.deviantart.net/7b5b/f/2017/160/c/5/test_post_please_ignore_by_noizave-dbc3a48.png", @site.image_url)
      end

      should "get the profile" do
        assert_equal("http://noizave.deviantart.com/", @site.profile_url)
      end

      should "get the artist name" do
        assert_equal("noizave", @site.artist_name)
      end

      should "get the tags" do
        assert_equal(%w[bar baz foo], @site.tags.map(&:first))
      end
    end

    context "The source for a login-only DeviantArt artwork page" do
      setup do
        @site = Sources::Site.new("http://noizave.deviantart.com/art/hidden-work-685458369")
        @site.get
      end

      should "get the image url" do
        assert_equal("http://orig14.deviantart.net/cb25/f/2017/160/1/9/hidden_work_by_noizave-dbc3r29.png", @site.image_url)
      end
    end
  end
end
