require 'test_helper'
require 'helpers/pool_archive_test_helper'

class PoolsControllerTest < ActionController::TestCase
  include PoolArchiveTestHelper
  include DefaultHelper

  context "The pools controller" do
    setup do
      Timecop.travel(1.month.ago) do
        @user = FactoryGirl.create(:user)
        @mod = FactoryGirl.create(:moderator_user)
      end
      CurrentUser.test!(@user)
      @post = FactoryGirl.create(:post)
      mock_pool_archive_service!
      PoolArchive.sqs_service.stubs(:merge?).returns(false)
      start_pool_archive_transaction
    end

    teardown do
      rollback_pool_archive_transaction
      CurrentUser.user = nil
    end

    context "index action" do
      setup do
        FactoryGirl.create(:pool, :name => "abc")
      end

      should "list all pools" do
        get :index
        assert_response :success
      end

      should "list all pools (with search)" do
        get :index, {:search => {:name_matches => "abc"}}
        assert_response :success
      end
    end

    context "show action" do
      setup do
        @pool = FactoryGirl.create(:pool)
      end

      should "render" do
        get :show, {:id => @pool.id}
        assert_response :success
      end
    end

    context "gallery action" do
      should "render" do
        pool = FactoryGirl.create(:pool)
        get :gallery, {:id => pool.id}
        assert_response :success
      end
    end

    context "new action" do
      should "render" do
        get :new, {}, { user_id: @user.id }
        assert_response :success
      end
    end

    context "create action" do
      should "create a pool" do
        assert_difference("Pool.count", 1) do
          post :create, {:pool => {:name => "xxx", :description => "abc"}}, {:user_id => @user.id}
        end
      end
    end

    context "edit action" do
      should "render" do
        pool = FactoryGirl.create(:pool)

        get :edit, { id: pool.id }, { user_id: @user.id }
        assert_response :success
      end
    end

    context "update action" do
      setup do
        @pool = FactoryGirl.create(:pool)
      end

      should "update a pool" do
        post :update, {:id => @pool.id, :pool => {:name => "xyz"}}, {:user_id => @user.id}
        @pool.reload
        assert_equal("xyz", @pool.name)
      end
    end

    context "revert action" do
      setup do
        @post_2 = FactoryGirl.create(:post)
        @pool = FactoryGirl.create(:pool, :post_ids => "#{@post.id}")
        CurrentUser.scoped(@user, "127.0.0.2") do
          @pool.update(post_ids: "#{@post.id} #{@post_2.id}")
        end
        @post_2.reload
        @pool.reload
      end

      should "revert to a previous version" do
        version = @pool.versions.first
        assert_equal([@post.id], version.post_ids)
        post :revert, {:id => @pool.id, :version_id => version.id}, {:user_id => @mod.id}
        @pool.reload
        assert_equal([@post.id], @pool.post_id_array)
      end

      should "not allow reverting to a previous version of another pool" do
        @pool2 = FactoryGirl.create(:pool)

        post :revert, { :id => @pool.id, :version_id => @pool2.versions.first.id }, {:user_id => @user.id}
        @pool2.reload
        @pool.reload

        assert_not_equal(@pool.name, @pool2.name)
        assert_response :missing
      end
    end
  end
end
