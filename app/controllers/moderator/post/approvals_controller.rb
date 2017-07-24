module Moderator
  module Post
    class ApprovalsController < ApplicationController
      before_filter :moderator_only
      skip_before_filter :api_check
      respond_to :json, :xml, :js

      def create
        post = ::Post.find(params[:post_id])
        @approval = post.approve!
        respond_with(:moderator, @approval)
      end
    end
  end
end
