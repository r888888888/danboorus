module Admin::UsersHelper
  def user_level_select(object, field)
    options = [
      ["Member", User::Levels::MEMBER],
      ["Gold", User::Levels::GOLD],
      ["Platinum", User::Levels::PLATINUM],
      ["Moderator", User::Levels::MODERATOR],
      ["Admin", User::Levels::ADMIN]
    ]
    select(object, field, options)
  end
end
