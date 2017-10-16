class UsersController < ApplicationController
  respond_to :html, :xml, :json
  skip_before_filter :api_check
  before_filter :member_only, only: [:index, :update]

  def new
    @user = User.new
    respond_with(@user)
  end

  def edit
    @user = User.find(params[:id])
    check_privilege(@user)
    respond_with(@user)
  end

  def index
    if params[:name].present?
      @user = User.find_by_name(params[:name])
      if @user.nil?
        raise "No user found with name: #{params[:name]}"
      else
        redirect_to user_path(@user)
      end
    else
      @users = User.search(params[:search]).order("users.id desc").paginate(params[:page], :limit => params[:limit], :search_count => params[:search])
      respond_with(@users) do |format|
        format.xml do
          render :xml => @users.to_xml(:root => "users")
        end
      end
    end
  end

  def search
  end

  def show
    @user = User.find(params[:id])
    @presenter = UserPresenter.new(@user)
    respond_with(@user, methods: @user.full_attributes)
  end

  def create
    @user = User.create(create_params)
    if @user.errors.empty?
      session[:user_id] = @user.id
    end
    @user.update(last_ip_addr: request.remote_ip)
    CurrentUser.user = @user
    CurrentUser.ip_addr = request.remote_ip
    respond_with(@user)
  end

  def update
    @user = User.find(params[:id])
    check_privilege(@user)
    @user.update(update_params)
    if @user.errors.any?
      flash[:notice] = @user.errors.full_messages.join("; ")
    else
      flash[:notice] = "Settings updated"
    end
    respond_with(@user, location: edit_user_path(@user))
  end

  def cache
    @user = User.find(params[:id])
    @user.update_cache
    render :nothing => true
  end

private

  def create_params
    params.require(:user).permit(:name, :password, :password_confirmation, :email)
  end

  def update_params
    params.require(:user).permit(:password, :password_confirmation, :email)
  end

  def check_privilege(user)
    raise User::PrivilegeError unless (user.id == CurrentUser.id || CurrentUser.is_admin?)
  end
end
