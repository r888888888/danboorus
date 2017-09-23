require 'test_helper'

class ForumSubscriptionsControllerTest < ActionController::TestCase
  include DefaultHelper

  def setup
    super

    @topic = FactoryGirl.create(:forum_topic)
    @post = FactoryGirl.create(:forum_post, topic: @topic)
  end

  context "#create" do
  end

  context "#destroy" do
  end
end
