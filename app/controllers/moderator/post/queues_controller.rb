module Moderator
  module Post
    class QueuesController < ApplicationController
      RANDOM_COUNT = 12
      
      respond_to :html, :json
      before_filter :moderator_only
      skip_before_filter :api_check

      def show
        if params[:per_page]
          cookies.permanent["mq_per_page"] = params[:per_page]
        end

        ::Post.without_timeout do
          @posts = ::Post.includes(:uploader).order("posts.id asc").pending_or_flagged.tag_match(params[:query]).paginate(params[:page], :limit => per_page)
          @posts.to_a
        end
        respond_with(@posts)
      end

    protected

      def per_page
        cookies["mq_per_page"] || params[:per_page] || 25
      end
    end
  end
end
