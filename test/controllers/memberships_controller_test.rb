require 'test_helper'

class MembershipsControllerTest < ActionController::TestCase
  include DefaultHelper

  context "new" do
    should "succeed" do
      get :new
      assert_response :success
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
end
