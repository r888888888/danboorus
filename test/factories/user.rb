FactoryGirl.define do
  factory(:user, aliases: [:creator, :updater]) do
    name {(rand(1_000_000) + 10).to_s}
    password "password"
    bcrypt_password_hash {User.bcrypt("password")}
    email {FFaker::Internet.email}
    default_image_size "large"
    level 20
    created_at {Time.now}
    last_logged_in_at {Time.now}
    favorite_count 0
    bit_prefs 0

    factory(:banned_user) do
      transient { ban_duration 3 }
      is_banned true
      after(:create) { |user, ctx| create(:ban, user: user, duration: ctx.ban_duration) }
    end

    factory(:member_user) do
      level 20
    end

    factory(:gold_user) do
      level 30
    end

    factory(:platinum_user) do
      level 31
    end

    factory(:moderator_user) do
      level 40
      after(:create) {|user| CurrentUser.scoped(user) {create(:membership, is_moderator: true)} if Booru.current.present?}
    end

    factory(:mod_user) do
      level 40
    end

    factory(:admin_user) do
      level 50
    end
  end
end

