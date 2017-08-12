class Membership < ActiveRecord::Base
	belongs_to :booru
	belongs_to :user
end
