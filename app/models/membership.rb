class Membership < ActiveRecord::Base
	belongs_to :booru
	belongs_to :user

  before_validation :initialize_booru
  before_validation :initialize_user

  def initialize_booru
    self.booru_id = Booru.current.id if Booru.current
  end

  def initialize_user
    self.user_id = CurrentUser.id
  end
end
