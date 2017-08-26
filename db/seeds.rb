raise "no PASSWORD supplied" if ENV["PASSWORD"].blank?

user = User.new(name: "albert", password: ENV["PASSWORD"], password_confirmation: ENV["PASSWORD"])
user.level = 50
user.save
CurrentUser.scoped(user, "127.0.0.1") do
  Booru.create(name: "home", desc: "homebooru", host: "localhost")
end
