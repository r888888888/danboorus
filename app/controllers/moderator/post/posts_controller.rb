module Moderator
  module Post
    class PostsController < ApplicationController
      before_filter :moderator_only, :only => [:delete, :undelete, :move_favorites, :confirm_delete, :confirm_move_favorites]
      before_filter :admin_only, :only => [:expunge]
      skip_before_filter :api_check

      respond_to :html, :json, :xml

      def confirm_delete
        @post = ::Post.find(params[:id])
      end

      def delete
        @post = ::Post.find(params[:id])
        if params[:commit] == "Delete"
          @post.delete!(params[:reason], :move_favorites => params[:move_favorites].present?)
        end
        redirect_to(post_path(@post))
      end

      def undelete
        @post = ::Post.find(params[:id])
        @post.undelete!
      end

      def confirm_move_favorites
        @post = ::Post.find(params[:id])
      end

      def move_favorites
        @post = ::Post.find(params[:id])
        if params[:commit] == "Submit"
          @post.give_favorites_to_parent
        end
        redirect_to(post_path(@post))
      end

      def expunge
        @post = ::Post.find(params[:id])
        @post.expunge!
      rescue StandardError => x
        @error = x
      end
    end
  end
end
