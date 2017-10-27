class CommentsController < ApplicationController
  respond_to :html, :json
  before_filter :basic_only, except: %i(index show)
  before_filter :load_comment, only: %i(update edit show)
  skip_before_filter :api_check

  def index
    if params[:group_by] == "comment" || request.format == Mime::ATOM
      index_by_comment
    elsif request.format == Mime::JS
      index_for_post
    else
      index_by_post
    end
  end

  def search
  end

  def new
    redirect_to booru_comments_path(Booru.current.slug)
  end

  def update
    @comment.update(update_params(@comment))
    respond_with(@comment, :location => booru_post_path(Booru.current.slug, @comment.post_id))
  end

  def create
    @comment = Comment.create(create_params)
    respond_with(@comment) do |format|
      format.html do
        if @comment.errors.any?
          if @comment.post
            redirect_to booru_post_path(Booru.current.slug, @comment.post), :notice => @comment.errors.full_messages.join("; ")
          else
            redirect_to booru_posts_path(Booru.current.slug, :notice => @comment.errors.full_messages.join("; ")
          end
        else
          redirect_to booru_post_path(Booru.current.slug, @comment.post), :notice => "Comment posted"
        end
      end
    end
  end

  def edit
    respond_with(@comment)
  end

  def show
    respond_with(@comment, methods: [:quoted_response])
  end

private
  def load_post
    @post = Booru.current.posts.find(params[:post_id])
  end

  def load_comment
    @comment = Booru.current.comments.find(params[:id])
  end

  def index_for_post
    @post = load_post()
    @comments = @post.comments
    @comments = @comments.visible(CurrentUser.user) unless params[:include_below_threshold]
    render :action => "index_for_post"
  end

  def index_by_post
    @posts = Post.where(booru_id: Booru.current.id).where("last_commented_at IS NOT NULL").tag_match(params[:tags]).reorder("last_commented_at DESC NULLS LAST").paginate(params[:page], :limit => 5, :search_count => params[:search])
    @posts.to_a # hack to force rails to eager load
    respond_with(@posts) do |format|
      format.xml do
        render :xml => @posts.to_xml(:root => "posts")
      end
    end
  end

  def index_by_comment
    @comments = Comment.search(params[:search]).paginate(params[:page], :limit => params[:limit], :search_count => params[:search])
    respond_with(@comments) do |format|
      format.atom do
        @comments = @comments.includes(:post, :creator).load
      end
      format.xml do
        render :xml => @comments.to_xml(:root => "comments")
      end
    end
  end

  def create_params
    x = params.fetch(:comment, {})

    if CurrentUser.is_moderator?
      x.permit(:post_id, :body, :is_sticky)
    else
      x.permit(:post_id, :body)
    end
  end

  def update_params(comment)
    x = params.fetch(:comment, {})

    if CurrentUser.is_moderator?
      x.permit(:body, :is_deleted, :is_sticky)
    elsif comment.editable_by?(CurrentUser.user)
      x.permit(:body)
    else
      x.permit()
    end
  end
end
