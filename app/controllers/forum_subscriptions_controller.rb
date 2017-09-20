class ForumSubscriptionsController < ApplicationController
  respond_to :html, :json
  before_filter :basic_only
  before_filter :load_topic

  def create
    subscription = ForumSubscription.where(:forum_topic_id => @forum_topic.id, :user_id => CurrentUser.user.id).first
    unless subscription
      ForumSubscription.create(:forum_topic_id => @forum_topic.id, :user_id => CurrentUser.user.id, :last_read_at => @forum_topic.updated_at)
    end
    respond_with(@forum_topic)
  end

  def destroy
    subscription = ForumSubscription.where(:forum_topic_id => @forum_topic.id, :user_id => CurrentUser.user.id).first
    if subscription
      subscription.destroy
    end
    respond_with(@forum_topic)
  end

private
  def per_page
    params[:limit] || 40
  end

  def load_topic
    @forum_topic = ForumTopic.find(params[:id])
  end
end
