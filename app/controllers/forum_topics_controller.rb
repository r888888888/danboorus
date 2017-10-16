class ForumTopicsController < ApplicationController
  respond_to :html, :json
  before_filter :basic_only, except: %i(index show)
  before_filter :normalize_search, only: %i(index)
  before_filter :load_topic, only: %i(edit show update)
  before_filter :check_user_access, only: %i(edit update)
  before_filter :check_mod_access, only: %i(show edit update)
  skip_before_filter :api_check

  def new
    @forum_topic = ForumTopic.new
    @forum_topic.original_post = ForumPost.new
    respond_with(@forum_topic)
  end

  def edit
    respond_with(@forum_topic)
  end

  def index
    params[:search] ||= {}
    params[:search][:order] ||= "sticky" if request.format == Mime::HTML

    @query = Booru.current.forum_topics.active.search(params[:search])
    @forum_topics = @query.paginate(params[:page], :limit => per_page, :search_count => params[:search])

    respond_with(@forum_topics) do |format|
      format.html do
        @forum_topics = @forum_topics.includes(:creator, :updater).load
      end
      format.atom do
        @forum_topics = @forum_topics.includes(:creator, :original_post).load
      end
      format.json do
        render :json => @forum_topics.to_json
      end
      format.xml do
        render :xml => @forum_topics.to_xml(:root => "forum-topics")
      end
    end
  end

  def show
    if request.format == Mime::HTML
      @forum_topic.mark_as_read!(CurrentUser.user)
    end
    @forum_posts = ForumPost.search(:topic_id => @forum_topic.id).order("forum_posts.id").paginate(params[:page])
    respond_with(@forum_topic) do |format|
      format.atom do
        @forum_posts = @forum_posts.reverse_order.includes(:creator).load
      end
    end
  end

  def create
    @forum_topic = ForumTopic.create(permit_params)
    respond_with(@forum_topic)
  end

  def update
    check_privilege(@forum_topic)
    @forum_topic.update(permit_params)
    respond_with(@forum_topic)
  end

  def mark_all_as_read
    CurrentUser.user.update_attribute(:last_forum_read_at, Time.now)
    ForumTopicVisit.prune!(CurrentUser.user)
    redirect_to forum_topics_path, :notice => "All topics marked as read"
  end

private

  def permit_params
    x = params.fetch(:forum_topic, {})
    if CurrentUser.is_moderator?
      x.permit(:title, {:original_post_attributes => [:body]}, :is_sticky, :is_locked, :is_deleted, :category_id, :mods_only)
    elsif @forum_topic.nil? || @forum_topic.editable_by?(CurrentUser.user)
      x.permit(:title, {:original_post_attributes => [:body]}, :category_id)
    else
      x.permit()
    end
  end

  def per_page
    params[:limit] || 40
  end

  def normalize_search
    if params[:title_matches]
      params[:search] ||= {}
      params[:search][:title_matches] = params.delete(:title_matches)
    end

    if params[:title]
      params[:search] ||= {}
      params[:search][:title] = params.delete(:title)
    end
  end

  def check_mod_access
    if @forum_topic.mods_only? && !CurrentUser.is_moderator?
      raise User::PrivilegeError
    end
  end

  def check_user_access
    if !@forum_topic.editable_by?(CurrentUser.user)
      raise User::PrivilegeError
    end
  end

  def load_topic
    @forum_topic = ForumTopic.find(params[:id])
  end
end
