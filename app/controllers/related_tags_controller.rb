class RelatedTagsController < ApplicationController
  respond_to :json
  respond_to :html, :only=>[:show]
  before_filter :require_reportbooru_key, only: [:update]

  def show
    @query = RelatedTagQuery.new(params[:query].to_s.downcase)
    respond_with(@query) do |format|
      format.json do
        render :json => @query.to_json
      end
    end
  end

  def update
    @tag = Tag.find_by_name(params[:name])
    @tag.related_tags = params[:related_tags]
    @tag.related_tags_updated_at = Time.now
    @tag.save

    render nothing: true
  end
end
