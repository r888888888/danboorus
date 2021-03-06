class ModAction < ApplicationRecord
  belongs_to_booru
  belongs_to_creator
  validates_presence_of :creator_id
  # attr_accessible :description

  def self.search(params = {})
    q = where("true")
    return q if params.blank?

    if params[:creator_id].present?
      q = q.where("creator_id = ?", params[:creator_id].to_i)
    end

    q
  end

  def self.log(desc)
    create(:description => desc)
  end
end
