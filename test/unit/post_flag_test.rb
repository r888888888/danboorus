require 'test_helper'

class PostFlagTest < ActiveSupport::TestCase
  context "In all cases" do
    setup do
      Timecop.travel(2.weeks.ago) do
        @alice = FactoryGirl.create(:gold_user)
      end
      CurrentUser.user = @alice
      CurrentUser.ip_addr = "127.0.0.2"
      @post = FactoryGirl.create(:post, :tag_string => "aaa")
    end

    teardown do
      CurrentUser.user = nil
      CurrentUser.ip_addr = nil
    end

    context "a gold user" do
      should "not be able to flag a post more than twice" do
        assert_difference("PostFlag.count", 1) do
          @post_flag = PostFlag.create(:post => @post, :reason => "aaa", :is_resolved => false)
        end

        assert_difference("PostFlag.count", 0) do
          @post_flag = PostFlag.create(:post => @post, :reason => "aaa", :is_resolved => false)
        end

        assert_equal(["have already flagged this post"], @post_flag.errors[:creator_id])
      end

      should "not be able to flag a deleted post" do
        @post.update_attribute(:is_deleted, true)
        assert_difference("PostFlag.count", 0) do
          @post_flag = PostFlag.create(:post => @post, :reason => "aaa", :is_resolved => false)
        end
        assert_equal(["Post is deleted"], @post_flag.errors.full_messages)
      end

      should "initialize its creator" do
        @post_flag = PostFlag.create(:post => @post, :reason => "aaa", :is_resolved => false)
        assert_equal(@alice.id, @post_flag.creator_id)
        assert_equal(IPAddr.new("127.0.0.2"), @post_flag.creator_ip_addr)
      end
    end
  end
end
