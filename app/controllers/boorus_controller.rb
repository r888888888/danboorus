class BoorusController < ApplicationController
  before_filter :basic_only
  before_filter :find_booru, only: [:edit, :update, :show, :destroy]

  def new
    @booru = Booru.new
  end

  def create
    @booru = Booru.create(booru_params.permit(:name, :desc))
    respond_with(@booru)
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

private

  def booru_params
    params.require(:booru)
  end

  def find_booru
    @booru = Booru.find(params[:booru_id])
  end
end
