class PostsController < ApplicationController
  before_filter :basic_only, :except => [:show, :show_seq, :index, :home, :random]
  before_filter :enable_cors, :only => [:index, :show]
  respond_to :html, :xml, :json

  def index
    if params[:sha256].present?
      @post = Post.find_by_sha256(params[:sha256])
      redirect_to booru_post_path(Booru.current.slug, @post)
    else
      limit = params[:limit] || (params[:tags] =~ /(?:^|\s)limit:(\d+)(?:$|\s)/ && $1) || CurrentUser.user.per_page
      @random = params[:random] || params[:tags] =~ /(?:^|\s)order:random(?:$|\s)/
      @post_set = PostSets::Post.new(tag_query, params[:page], limit, raw: params[:raw], random: @random, format: params[:format])
      @posts = @post_set.posts
      respond_with(@posts) do |format|
        format.atom
        format.xml do
          render :xml => @posts.to_xml(:root => "posts")
        end
      end
    end
  end

  def show
    @post = Post.find(params[:id])
    
    include_deleted = @post.is_deleted? || (@post.parent_id.present? && @post.parent.is_deleted?)
    @parent_post_set = PostSets::PostRelationship.new(@post.parent_id, :include_deleted => include_deleted)
    @children_post_set = PostSets::PostRelationship.new(@post.id, :include_deleted => include_deleted)
    respond_with(@post)
  end

  def show_seq
    context = PostSearchContext.new(params)
    if context.post_id
      redirect_to(booru_post_path(Booru.current.slug, context.post_id, :tags => params[:tags]))
    else
      redirect_to(booru_post_path(Booru.current.slug, params[:id], :tags => params[:tags]))
    end
  end

  def update
    @post = Post.find(params[:id])

    if @post.visible?
      @post.update(update_params)
    end

    save_recent_tags
    respond_with_post_after_update(@post)
  end

  def revert
    @post = Post.find(params[:id])
    @version = @post.versions.find(params[:version_id])

    if @post.visible?
      @post.revert_to!(@version)
    end
    
    respond_with(@post) do |format|
      format.js
    end
  end

  def copy_notes
    @post = Post.find(params[:id])
    @other_post = Post.find(params[:other_post_id].to_i)
    @post.copy_notes_to(@other_post)
    
    if @post.errors.any?
      @error_message = @post.errors.full_messages.join("; ")
      render :json => {:success => false, :reason => @error_message}.to_json, :status => 400
    else
      head :no_content
    end
  end

  def random
    @post = Post.tag_match(params[:tags]).random
    raise ActiveRecord::RecordNotFound if @post.nil?
    respond_with(@post) do |format|
      format.html { redirect_to booru_post_path(Booru.current.slug, @post, :tags => params[:tags]) }
    end
  end

  def mark_as_translated
    @post = Post.find(params[:id])
    @post.mark_as_translated(params[:post])
    respond_with_post_after_update(@post)
  end

private
  def update_params
    x = params.fetch(:post, {})

    if CurrentUser.is_moderator?
      x = x.permit(:source, :rating, :tag_string, :old_tag_string, :old_parent_id, :old_source, :old_rating, :parent_id, :is_rating_locked, :is_note_locked, :is_status_locked)
    elsif CurrentUser.is_basic?
      x = x.permit(:source, :rating, :tag_string, :old_tag_string, :old_parent_id, :old_source, :old_rating, :parent_id)
    end

    x
  end

  def tag_query
    params[:tags] || (params[:post] && params[:post][:tags])
  end

  def save_recent_tags
    if @post
      tags = Tag.scan_tags(@post.tag_string)
      tags += Tag.scan_tags(cookies[:recent_tags])
      tags = tags.uniq.slice(0, 30)
      cookies[:recent_tags] = tags.join(" ")
    end
  end

  def respond_with_post_after_update(post)
    respond_with(post) do |format|
      format.html do
        if post.errors.any?
          @error_message = post.errors.full_messages.join("; ")
          render :template => "static/error", :status => 500
        else
          response_params = {:tags => params[:tags_query], :pool_id => params[:pool_id]}
          response_params.reject!{|key, value| value.blank?}
          redirect_to booru_post_path(Booru.current.slug, post, response_params)
        end
      end

      format.json do
        render :json => post.to_json
      end
    end
  end
end
