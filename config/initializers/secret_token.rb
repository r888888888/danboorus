Rails.application.config.action_dispatch.session = {
  :key    => '_danboorus_session',
  :secret => ENV["SESSION_SECRET_KEY"]
}
Rails.application.config.secret_token = ENV["SECRET_TOKEN"]
