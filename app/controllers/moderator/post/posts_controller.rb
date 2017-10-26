module Moderator
  module Post
    class PostsController < ApplicationController
      before_filter :find_post
      before_filter :moderator_only
      skip_before_filter :api_check
      respond_to :html, :json

      def confirm_delete
      end

      def delete
        if params[:commit] == "Delete"
          @post.delete!(params[:reason], :move_favorites => params[:move_favorites].present?)
        end
        redirect_to(booru_post_path(Booru.current, (@post))
      end

      def undelete
        @post.undelete!
      end

      def confirm_move_favorites
      end

      def move_favorites
        if params[:commit] == "Submit"
          @post.give_favorites_to_parent
        end
        redirect_to(booru_post_path(Booru.current, (@post))
      end

      def expunge
        @post.expunge!
      rescue StandardError => x
        @error = x
      end

    private

      def find_post
        @post = Booru.current.posts.find(params[:id])
      end
    end
  end
end
