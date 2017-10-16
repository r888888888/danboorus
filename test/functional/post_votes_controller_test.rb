require 'test_helper'

class PostVotesControllerTest < ActionController::TestCase
  include DefaultHelper

  context "The post vote controller" do
    setup do
      @user = FactoryGirl.create(:gold_user)
      CurrentUser.scoped(@user) do
        @post = FactoryGirl.create(:post)
      end
    end

    teardown do
      CurrentUser.user = nil
      CurrentUser.ip_addr = nil
    end

    context "create action" do
      should "not allow anonymous users to vote" do
        p1 = FactoryGirl.create(:post)
        CurrentUser.scoped(AnonymousUser.new) do
          post :create, {:post_id => p1.id, :score => "up", :format => "js"}
        end

        assert_response 403
        assert_equal(0, p1.reload.score)
      end

      should "not allow banned users to vote" do
        CurrentUser.scoped(FactoryGirl.create(:banned_user)) do
          p1 = FactoryGirl.create(:post)
          post :create, {:post_id => p1.id, :score => "up", :format => "js"}, {:user_id => CurrentUser.id}

          assert_response 403
          assert_equal(0, p1.reload.score)
        end
      end

      should "increment a post's score if the score is positive" do
        post :create, {:post_id => @post.id, :score => "up", :format => "js"}, {:user_id => @user.id}
        assert_response :success
        @post.reload
        assert_equal(1, @post.score)
      end

      context "that fails" do
        should "return a 500" do
          post :create, {:post_id => @post.id, :score => "up", :format => "json"}, {:user_id => @user.id}
          post :create, {:post_id => @post.id, :score => "up", :format => "json"}, {:user_id => @user.id}
          assert_equal("{\"success\": false, \"reason\": \"You have already voted for this post\"}", response.body.strip)
        end
      end

      context "for a post that has already been voted on" do
        setup do
          @post.vote!("up")
        end

        should "fail silently on an error" do
          assert_nothing_raised do
            post :create, {:post_id => @post.id, :score => "up", :format => "js"}, {:user_id => @user.id}
          end
        end
      end
    end
  end
end
