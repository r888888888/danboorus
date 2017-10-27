class ForumPostsController < ApplicationController
  respond_to :html, :json, :js
  before_filter :basic_only, except: %i(index show search)
  before_filter :load_post, only: %i(edit show update)
  before_filter :check_mod_access, only: %i(show edit update)
  before_filter :check_user_access, only: %i(edit update)
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
      redirect_to(booru_forum_topic_path(Booru.current.slug, @forum_post.topic, page: params[:page]))
    else
      respond_with(@forum_post)
    end
  end

  def create
    @forum_post = ForumPost.create(create_params)
    page = @forum_post.topic.last_page if @forum_post.topic.last_page > 1
    respond_with(@forum_post, location: booru_forum_topic_path(Booru.current.slug, @forum_post.topic, page: page))
  end

  def update
    @forum_post.update(update_params(@forum_post))
    page = @forum_post.forum_topic_page if @forum_post.forum_topic_page > 1
    respond_with(@forum_post, location: booru_forum_topic_path(Booru.current.slug, @forum_post.topic, page: page, anchor: "forum_post_#{@forum_post.id}"))
  end

private
  def load_post
    @forum_post = Booru.current.forum_posts.find(params[:id])
    @forum_topic = @forum_post.topic
  end

  def check_mod_access
    if @forum_topic.mods_only? && !CurrentUser.is_moderator?
      raise User::PrivilegeError.new
    end
  end

  def check_user_access
    if !@forum_post.editable_by?(CurrentUser.user)
      raise User::PrivilegeError.new      
    end
  end

  def update_params(post)
    x = params.fetch(:forum_post, {})
    if CurrentUser.is_moderator?
      x.permit(:body, :topic_id, :is_locked, :is_sticky, :is_deleted)
    elsif(post.editable_by?(CurrentUser.user))
      x.permit(:body, :is_deleted)
    end
  end

  def create_params
    x = params.fetch(:forum_post, {})
    if CurrentUser.is_moderator?
      x.permit(:body, :topic_id, :is_locked, :is_sticky, :is_deleted)
    else
      x.permit(:body, :topic_id)
    end
  end
end
