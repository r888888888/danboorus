class BansController < ApplicationController
  before_filter :moderator_only, :except => [:show, :index]
  before_filter :load_ban, only: [:edit, :show, :update, :destroy]
  respond_to :html, :xml, :json

  def new
    @ban = Ban.new(ban_params)
  end

  def edit
  end

  def index
    @bans = Ban.search(params[:search]).paginate(params[:page], :limit => params[:limit])
    respond_with(@bans) do |fmt|
      fmt.html { @bans = @bans.includes(:user, :banner) }
    end
  end

  def show
    respond_with(@ban)
  end

  def create
    @ban = Ban.create(ban_params)

    if @ban.errors.any?
      render :action => "new"
    else
      redirect_to ban_path(@ban), :notice => "Ban created"
    end
  end

  def update
    if @ban.update_attributes(ban_params)
      redirect_to ban_path(@ban), :notice => "Ban updated"
    else
      render :action => "edit"
    end
  end

  def destroy
    @ban.destroy
    redirect_to bans_path, :notice => "Ban destroyed"
  end

private

  def ban_params
    params.require(:ban).permit(:reason, :duration, :user_id, :user_name)
  end
  
  def load_ban
    @ban = Booru.current.bans.find(params[:id])
  end
end
