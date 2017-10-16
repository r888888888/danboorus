class UserFeedbacksController < ApplicationController
  before_filter :gold_only, :only => [:new, :edit, :create, :update, :destroy]
  respond_to :html, :xml, :json

  def new
    @user_feedback = UserFeedback.new(create_params)
    respond_with(@user_feedback)
  end

  def edit
    @user_feedback = UserFeedback.visible.find(params[:id])
    check_privilege(@user_feedback)
    respond_with(@user_feedback)
  end

  def show
    @user_feedback = UserFeedback.visible.find(params[:id])
    respond_with(@user_feedback)
  end

  def index
    @search = UserFeedback.visible.search(params[:search])
    @user_feedbacks = @search.paginate(params[:page], :limit => params[:limit]).order("created_at desc")
    respond_with(@user_feedbacks) do |format|
      format.xml do
        render :xml => @user_feedbacks.to_xml(:root => "user-feedbacks")
      end
    end
  end

  def create
    @user_feedback = UserFeedback.create(create_params)
    respond_with(@user_feedback)
  end

  def update
    @user_feedback = UserFeedback.visible.find(params[:id])
    check_privilege(@user_feedback)
    @user_feedback.update_attributes(create_params)
    respond_with(@user_feedback)
  end

  def destroy
    @user_feedback = UserFeedback.visible.find(params[:id])
    check_privilege(@user_feedback)
    @user_feedback.destroy
    respond_with(@user_feedback)
  end

private
  def create_params
    params.fetch(:user_feedback, {}).permit(:body, :user, :user_id, :user_name, :disable_dmail_notification)
  end

  def check_privilege(user_feedback)
    raise User::PrivilegeError unless user_feedback.editable_by?(CurrentUser.user)
  end
end
