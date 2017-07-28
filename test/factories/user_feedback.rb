FactoryGirl.define do
  factory(:user_feedback) do
    user
    body {FFaker::Lorem.words.join(" ")}
  end
end
