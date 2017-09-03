FactoryGirl.define do
  factory(:forum_topic) do
    title {FFaker::Lorem.words.join(" ")}
    is_sticky false
    is_locked false
    category_id 0
    mods_only false

    factory(:mod_up_forum_topic) do
      mods_only true 
    end
  end
end
