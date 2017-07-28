FactoryGirl.define do
  factory(:bulk_update_request) do |f|
    title "xxx"
    skip_secondary_validations true
  end
end
