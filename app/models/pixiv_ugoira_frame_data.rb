class PixivUgoiraFrameData < ApplicationRecord
  attr_accessible :post_id, :data, :content_type
  serialize :data
  belongs_to :booru
end
