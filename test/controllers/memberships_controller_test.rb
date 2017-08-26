require 'test_helper'

class MembershipsControllerTest < ActionController::TestCase
  include DefaultHelper

  context "show" do
    context "when i have a membership" do
      setup do
        @membership = Membership.create
      end

      should "succeed" do
        get :show
        assert_response :success
      end      
    end

    context "when i don't have a membership" do
      should "succeed" do
        get :show
        assert_response :success
      end      
    end
  end

  context "create" do
    should "succeed" do
      assert_difference("Membership.count") do
        post :create
      end
      @membership = Membership.last
      assert_redirected_to membership_path(@membership)
    end
  end

  context "show" do
    setup do
      @membership = Membership.create
    end

    should "succeed" do
      get :show
      assert_response :success
    end
  end

  context "destroy" do
    setup do
      @membership = Membership.create
    end

    should "succeed" do
      assert_difference("Membership.count", -1) do
        delete :destroy
        assert_redirected_to(new_membership_path)
      end
    end
  end
end
