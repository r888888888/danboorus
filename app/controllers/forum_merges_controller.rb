class ForumTopicsController < ApplicationController
  respond_to :html, :json
  before_filter :moderator_only
  before_filter :load_topic

  def new
  end

  def create
    @merged_topic = ForumTopic.find(params[:merged_id])
    @forum_topic.merge(@merged_topic)
    redirect_to booru_forum_topic_path(Booru.current, @merged_topic)
  end

private

  def load_topic
    @forum_topic = ForumTopic.find(params[:id])
  end
end
