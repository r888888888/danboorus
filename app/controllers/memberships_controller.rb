class MembershipsController < ApplicationController
  before_filter :find_membership, only: [:edit, :update, :show, :destroy]
  
  def new
    @membership = Membership.new
  end

  def create
    @membership = Membership.create
    respond_with(@membership)
  end

  def show
  end

  def destroy
  end

private

  def find_membership
    @membership = Membership.where(user_id: CurrentUser.id, booru_id: Booru.current.id)
  end
end
