FactoryGirl.define do
  factory(:tag) do
    name {"#{FFaker::Name.first_name.downcase}#{rand(1000)}"}
    post_count 0
    related_tags ""
    related_tags_updated_at {Time.now}
  end
end
