# Load the Rails application.
require File.expand_path('../application', __FILE__)

Bundler.require(*Rails.groups)
Dotenv.load(".env.local", ".env.development", ".env.production", ".env", "/run/secrets/danboorus_env")

# Initialize the Rails application.
Rails.application.initialize!
