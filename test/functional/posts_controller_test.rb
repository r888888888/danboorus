require "test_helper"

class PostsControllerTest < ActionController::TestCase
  include DefaultHelper

  context "The posts controller" do
    setup do
      @user = Timecop.travel(1.month.ago) {FactoryGirl.create(:user)}
      CurrentUser.user = @user
      CurrentUser.ip_addr = "127.0.0.1"
      @post = FactoryGirl.create(:post, :uploader_id => @user.id, :tag_string => "aaaa")
    end

    teardown do
      CurrentUser.user = nil
      CurrentUser.ip_addr = nil
    end
    
    context "index action" do
      should "render" do
        get :index
        assert_response :success
      end

      context "with a search" do
        should "render" do
          get :index, {:tags => "aaaa"}
          assert_response :success
        end
      end

      context "with an sha256 param" do
        should "render" do
          get :index, { sha256: @post.sha256 }
          assert_redirected_to(@post)
        end
      end
    end

    context "show_seq action" do
      should "render" do
        posts = FactoryGirl.create_list(:post, 3)

        get :show_seq, { seq: "prev", id: posts[1].id }
        assert_redirected_to(posts[2])

        get :show_seq, { seq: "next", id: posts[1].id }
        assert_redirected_to(posts[0])
      end
    end

    context "random action" do
      should "render" do
        get :random, { tags: "aaaa" }
        assert_redirected_to(booru_post_path(Booru.current.slug, (@post, tags: "aaaa"))
      end
    end

    context "show action" do
      should "render" do
        get :show, {:id => @post.id}
        assert_response :success
      end
    end

    context "update action" do
      should "work" do
        post :update, {:id => @post.id, :post => {:tag_string => "bbb"}}, {:user_id => @user.id}
        assert_redirected_to booru_post_path(Booru.current.slug, (@post)

        @post.reload
        assert_equal("bbb", @post.tag_string)
      end

      should "ignore restricted params" do
        post :update, {:id => @post.id, :post => {:last_noted_at => 1.minute.ago}}, {:user_id => @user.id}
        assert_redirected_to booru_post_path(Booru.current.slug, (@post)

        @post.reload
        assert_nil(@post.last_noted_at)
      end
    end

    context "revert action" do
      setup do
        PostArchive.stubs(:enabled?).returns(true)
        PostArchive.sqs_service.stubs(:merge?).returns(false)
        @post.update(tag_string: "zzz")
      end

      should "work" do
        @version = @post.versions.first
        assert_equal("aaaa", @version.tags)
        post :revert, {:id => @post.id, :version_id => @version.id}, {:user_id => @user.id}
        assert_redirected_to booru_post_path(Booru.current.slug, (@post)
        @post.reload
        assert_equal("aaaa", @post.tag_string)
      end

      should "not allow reverting to a previous version of another post" do
        @post2 = FactoryGirl.create(:post, :uploader_id => @user.id, :tag_string => "herp")

        post :revert, { :id => @post.id, :version_id => @post2.versions.first.id }, {:user_id => @user.id}
        @post.reload

        assert_not_equal(@post.tag_string, @post2.tag_string)
        assert_response :missing
      end
    end
  end
end
