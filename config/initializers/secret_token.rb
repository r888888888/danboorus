Rails.application.config.action_dispatch.session = {
  :key    => '_danboorus_session',
  :secret => ENV["DANBOORU_SESSION_SECRET_KEY"]
}
Rails.application.config.secret_token = ENV["DANBOORU_SESSION_SECRET_TOKEN"]
Rails.application.config.secret_key_base = ENV["DANBOORU_SECRET_KEY_BASE"]
