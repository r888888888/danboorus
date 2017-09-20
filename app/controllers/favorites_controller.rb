class FavoritesController < ApplicationController
  before_filter :basic_only, except: [:index]
  respond_to :html, :json
  skip_before_filter :api_check

  def index
    if params[:tags]
      redirect_to(posts_path(:tags => params[:tags]))
    else
      user_id = params[:user_id] || CurrentUser.user.id
      @user = User.find(user_id)

      if @user.hide_favorites?
        raise User::PrivilegeError.new
      end

      @favorite_set = PostSets::Favorite.new(user_id, params[:page], params)
      respond_with(@favorite_set.posts)
    end
  end

  def create
    if CurrentUser.favorite_limit.nil? || CurrentUser.favorite_count < CurrentUser.favorite_limit
      @post = Booru.current.posts.find(params[:post_id])
      @post.add_favorite!(CurrentUser.user)
    else
      @error_msg = "You can only keep up to #{CurrentUser.favorite_limit} favorites. Upgrade your account to save more."
    end

    respond_with(@post) do |format|
      format.html do
        redirect_to(post_path(@post))
      end
      format.js
      format.json do
        if @post
          render json: {success: true}.to_json
        else
          render json: {success: false, reason: @error_msg}.to_json, status: 422
        end
      end
    end
  end

  def destroy
    @post = Booru.current.posts.where(id: params[:id]).first

    if @post
      @post.remove_favorite!(CurrentUser.user)
      path = post_path(@post)
    else
      Favorite.remove(booru_id: Booru.current.id, post_id: params[:id], user: CurrentUser.user)
      path = posts_path
    end

    respond_with(@post) do |format|
      format.html do
        redirect_to(path)
      end
      format.js
      format.json do
        render json: {success: true}.to_json
      end
    end
  end
end
