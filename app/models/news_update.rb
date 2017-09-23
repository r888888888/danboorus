class NewsUpdate < ApplicationRecord
  belongs_to_creator
  belongs_to_updater
  scope :recent, lambda {where("created_at >= ?", 2.weeks.ago).order("created_at desc").limit(5)}

  def initialize_creator
    self.creator_id = CurrentUser.id
  end

  def initialize_updater
    self.updater_id = CurrentUser.id
  end
end
