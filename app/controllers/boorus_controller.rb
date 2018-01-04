class BoorusController < ApplicationController
  before_filter :basic_only, only: [:edit, :update, :destroy, :create]
  before_filter :find_booru, only: [:edit, :update, :show, :destroy]
  respond_to :html

  def new
    @booru = Booru.new
  end

  def create
    @booru = Booru.create(booru_params.permit(:name, :desc))
    respond_with(@booru, location: booru_path(@booru.slug))
  end

  def edit
  end

  def update
    @booru.update(booru_params.permit(:desc))
  end

  def show
  end

  def destroy
  end

  def index
    @boorus = Booru.paginate(params[:page])
  end

private

  def booru_params
    params.require(:booru)
  end

  def find_booru
    @booru = Booru.find_by_slug(params[:id])
  end
end
