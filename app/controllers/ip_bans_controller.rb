class IpBansController < ApplicationController
  respond_to :html, :xml, :json
  before_filter :moderator_only

  def new
    @ip_ban = IpBan.new
  end

  def create
    @ip_ban = IpBan.create(params[:ip_ban])
    respond_with(@ip_ban, :location => booru_ip_bans_path(Booru.current.slug))
  end

  def index
    @search = IpBan.search(params[:search])
    @ip_bans = @search.order("id desc").paginate(params[:page], :limit => params[:limit])
    respond_with(@ip_bans)
  end

  def destroy
    @ip_ban = IpBan.find(params[:id])
    @ip_ban.destroy
    respond_with(@ip_ban)
  end
end
