class PoolsController < ApplicationController
  respond_to :html, :xml, :json, :js
  before_filter :basic_only, :except => [:index, :show, :gallery]
  before_filter :moderator_only, :only => [:destroy]

  def new
    @pool = Pool.new
    respond_with(@pool)
  end

  def edit
    @pool = Pool.find(params[:id])
    respond_with(@pool)
  end

  def index
    @pools = Pool.search(params[:search]).order("updated_at desc").paginate(params[:page], :limit => params[:limit], :search_count => params[:search])
    respond_with(@pools) do |format|
      format.xml do
        render :xml => @pools.to_xml(:root => "pools")
      end
    end
  end

  def gallery
    limit = params[:limit] || CurrentUser.user.per_page
    @pools = Pool.series.search(params[:search]).order("updated_at desc").paginate(params[:page], :limit => limit, :search_count => params[:search])
    @post_set = PostSets::PoolGallery.new(@pools)
  end

  def show
    @pool = Pool.find(params[:id])
    @post_set = PostSets::Pool.new(@pool, params[:page])
    respond_with(@pool)
  end

  def create
    @pool = Pool.create(create_params)
    flash[:notice] = "Pool created"
    respond_with(@pool)
  end

  def update
    @pool = Pool.find(params[:id])
    @pool.update(update_params)
    unless @pool.errors.any?
      flash[:notice] = "Pool updated"
    end
    respond_with(@pool)
  end

  def revert
    @pool = Pool.find(params[:id])
    @version = @pool.versions.find(params[:version_id])
    @pool.revert_to!(@version)
    flash[:notice] = "Pool reverted"
    respond_with(@pool) do |format|
      format.js
    end
  end

private
  
  def create_params
    x = params.require(:pool)
    if CurrentUser.is_moderator?
      x.permit(:name, :description, :post_ids, :category, :is_active, :is_deleted)
    else
      x.permit(:name, :description, :post_ids, :category, :is_active)
    end
  end

  def update_params
    x = params.require(:pool)
    if CurrentUser.is_moderator?
      x.permit(:name, :description, :post_ids, :category, :is_active, :is_deleted)
    else
      x.permit(:name, :description, :post_ids, :category, :is_active)
    end
  end
end
