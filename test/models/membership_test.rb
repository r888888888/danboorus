require 'test_helper'

class MembershipTest < ActiveSupport::TestCase
  include DefaultHelper

  context "a new membership" do
    subject {Membership.new}

    should "initialize its fields" do
      subject.save
      assert_equal(Booru.current.id, subject.booru_id)
      assert_equal(CurrentUser.id, subject.user_id)
    end
  end
end
