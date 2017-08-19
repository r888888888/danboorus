module Admin::UsersHelper
  def user_level_select(object, field)
    options = [
      ["Basic", User::Levels::BASIC],
      ["Gold", User::Levels::GOLD],
      ["Platinum", User::Levels::PLATINUM],
      ["Admin", User::Levels::ADMIN]
    ]
    select(object, field, options)
  end
end
