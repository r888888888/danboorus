class MembershipsController < ApplicationController
  before_filter :find_membership, only: [:edit, :update, :show, :destroy]
  respond_to :html, :json
  
  def create
    @membership = Membership.create
    respond_with(@membership)
  end

  def show
  end

  def destroy
    @membership.destroy
    respond_with(@membership, location: new_membership_path)
  end

private

  def find_membership
    @membership = Membership.where(user_id: CurrentUser.id, booru_id: Booru.current.id).first
  end
end
