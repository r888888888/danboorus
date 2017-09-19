class PixivUgoiraFrameData < ApplicationRecord
  serialize :data
  belongs_to_booru
end
