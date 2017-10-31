class WikiPagesController < ApplicationController
  respond_to :html, :xml, :json, :js
  before_filter :basic_only, :except => [:index, :search, :show, :show_or_new, :destroy]
  before_filter :normalize_search_params, :only => [:index]
  
  def new
    @wiki_page = WikiPage.new(params[:wiki_page])
    respond_with(@wiki_page)
  end

  def edit
    @wiki_page = WikiPage.find(params[:id])
    respond_with(@wiki_page)
  end

  def index
    @wiki_pages = WikiPage.search(params[:search]).paginate(params[:page], :limit => params[:limit], :search_count => params[:search])
    respond_with(@wiki_pages) do |format|
      format.html do
        if params[:page].nil? || params[:page].to_i == 1
          if @wiki_pages.length == 1
            redirect_to(booru_wiki_page_path(Booru.current.slug, @wiki_pages.first))
          elsif @wiki_pages.length == 0 && params[:search][:title].present? && params[:search][:title] !~ /\*/
            redirect_to(booru_wiki_pages_path(Booru.current.slug, :search => {:title => "*#{params[:search][:title]}*"}))
          end
        end
      end
      format.xml do
        render :xml => @wiki_pages.to_xml(:root => "wiki-pages")
      end
    end
  end

  def search
  end

  def show
    if params[:id] =~ /\A\d+\Z/
      @wiki_page = WikiPage.find(params[:id])
    else
      @wiki_page = WikiPage.find_by_title(params[:id])
      if @wiki_page.nil? && request.format.symbol == :html
        redirect_to show_or_new_booru_wiki_pages_path(Booru.current.slug, :title => params[:id])
        return
      end
    end
    
    respond_with(@wiki_page)
  end

  def create
    @wiki_page = WikiPage.create(params[:wiki_page])
    respond_with(@wiki_page)
  end

  def update
    @wiki_page = WikiPage.find(params[:id])
    @wiki_page.update_attributes(params[:wiki_page])
    respond_with(@wiki_page)
  end

  def destroy
    @wiki_page = WikiPage.find(params[:id])
    @wiki_page.update_attributes(:is_deleted => true)
    respond_with(@wiki_page)
  end

  def revert
    @wiki_page = WikiPage.find(params[:id])
    @version = @wiki_page.versions.find(params[:version_id])
    @wiki_page.revert_to!(@version)
    flash[:notice] = "Page was reverted"
    respond_with(@wiki_page)
  end

  def show_or_new
    @wiki_page = WikiPage.find_by_title(params[:title])
    if @wiki_page
      redirect_to booru_wiki_page_path(Booru.current.slug, @wiki_page)
    else
      @wiki_page = WikiPage.new(:title => params[:title])
      respond_with(@wiki_page)
    end
  end

private
  def normalize_search_params
    if params[:title]
      params[:search] ||= {}
      params[:search][:title] = params.delete(:title)
    end
  end
end
