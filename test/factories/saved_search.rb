FactoryGirl.define do
  factory(:saved_search) do
    query { FFaker::Lorem.words }
    user
  end
end
