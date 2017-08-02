require 'test_helper'

module Downloads
  class DeviantArtTest < ActiveSupport::TestCase
    context "a download for a deviant art html page" do
      setup do
        @source = "http://starbitt.deviantart.com/art/09271X-636962118"
        @tempfile = Tempfile.new("danbooru-test")
        @download = Downloads::File.new(@source, @tempfile.path)
        @download.download!
      end

      should "set the html page as the source" do
        assert_equal("https://orig00.deviantart.net/82ef/f/2016/271/7/1/aaaaaa_by_starbitt-daj8b46.gif", @download.source)
      end

      should "work" do
        assert_equal(2948, ::File.size(@tempfile.path))
      end
    end
  end
end
