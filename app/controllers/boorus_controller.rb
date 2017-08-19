class BoorusController < ApplicationController
  before_filter :find_booru, only: [:edit, :update, :show, :destroy]

  def new
    @booru = Booru.new
  end

  def create
    @booru = Booru.create(params.require(:booru).permit(:name, :desc))
    respond_with(@booru)
  end

  def edit
  end

  def update
    @booru.update(params.require(:booru).permit(:desc))
  end

  def show
  end

  def destroy
  end

private

  def find_booru
    @booru = Booru.find(params[:booru_id])
  end
end
