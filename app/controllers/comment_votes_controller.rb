class CommentVotesController < ApplicationController
  respond_to :js, :json
  before_filter :load_comment
  before_filter :member_only
  skip_before_filter :api_check

  def create
    @comment_vote = @comment.vote!(params[:score])
  rescue CommentVote::Error, ActiveRecord::RecordInvalid => x
    @error = x
    render status: 422
  end

  def destroy
    @comment.unvote!
  rescue CommentVote::Error => x
    @error = x
    render status: 422
  end

private
  
  def load_comment
    @comment = Booru.current.comments.find(params[:comment_id])
  end
end
