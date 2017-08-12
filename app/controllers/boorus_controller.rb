class BoorusController < ApplicationController
  before_filter :find_booru, only: [:edit, :update, :show, :destroy]

  def new
  end

  def create
  end

  def edit
  end

  def update
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
