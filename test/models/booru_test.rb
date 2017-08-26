require 'test_helper'

class BooruTest < ActiveSupport::TestCase
  context "creating a new booru" do
    setup do
      CurrentUser.test!(FactoryGirl.create(:user))
    end

    teardown do
      CurrentUser.clear!
    end

    subject {Booru.new(name: "it's lit fam", host: "localhost")}

    should "initialize the slug" do
      subject.save
      assert_equal("it-s-lit-fam", subject.slug)
    end
  end
end
