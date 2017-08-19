class ForumPostsController < ApplicationController
  respond_to :html, :json, :js
  before_filter :member_only, except: %i(index show search)
  before_filter :load_post, only: %i(edit show update destroy undelete)
  before_filter :check_min_level, only: %i(edit show update destroy undelete)
  skip_before_filter :api_check
  
  def new
    if params[:topic_id]
      @forum_topic = Booru.current.forum_topics.find(params[:topic_id]) 
      raise User::PrivilegeError.new unless @forum_topic.visible?(CurrentUser.user)
    end
    if params[:post_id]
      quoted_post = Booru.current.forum_posts.find(params[:post_id])
      raise User::PrivilegeError.new unless quoted_post.topic.visible?(CurrentUser.user)
    end
    @forum_post = ForumPost.new_reply(params)
    respond_with(@forum_post)
  end

  def edit
    respond_with(@forum_post)
  end

  def index
    @query = ForumPost.search(params[:search])
    @forum_posts = @query.includes(:topic).order("forum_posts.id DESC").paginate(params[:page], limit: params[:limit], search_count: params[:search])
    respond_with(@forum_posts)
  end

  def search
  end

  def show
    if request.format == "text/html" && @forum_post.id == @forum_post.topic.original_post.id
      redirect_to(forum_topic_path(@forum_post.topic, page: params[:page]))
    else
      respond_with(@forum_post)
    end
  end

  def create
    @forum_post = ForumPost.create(create_params)
    page = @forum_post.topic.last_page if @forum_post.topic.last_page > 1
    respond_with(@forum_post, location: forum_topic_path(@forum_post.topic, page: page))
  end

  def update
    @forum_post.update(update_params(@forum_post))
    page = @forum_post.forum_topic_page if @forum_post.forum_topic_page > 1
    respond_with(@forum_post, location: forum_topic_path(@forum_post.topic, page: page, anchor: "forum_post_#{@forum_post.id}"))
  end

private
  def load_post
    @forum_post = Booru.current.forum_posts.find(params[:id])
    @forum_topic = @forum_post.topic
  end

  def check_min_level
    if CurrentUser.user.level < @forum_topic.min_level
      respond_with(@forum_topic) do |fmt|
        fmt.html do
          flash[:notice] = "Access denied"
          redirect_to forum_topics_path
        end

        fmt.json do
          render nothing: true, status: 403
        end
      end

      return false
    end
  end

  def update_params(post)
    params.require(:forum_post).tap do |x|
      if CurrentUser.is_moderator?
        x.permit(:body, :topic_id, :is_locked, :is_sticky, :is_deleted)
      elsif(post.editable_by?(CurrentUser.user))
        x.permit(:body, :is_deleted)
      end
    end
  end

  def create_params
    params.require(:forum_post).tap do |x|
      if CurrentUser.is_moderator?
        x.permit(:body, :topic_id, :is_locked, :is_sticky, :is_deleted)
      else
        x.permit(:body, :topic_id)
      end
    end
  end
end
