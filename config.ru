# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment',  __FILE__)

if defined?(Unicorn) && Rails.env.production?
  # Unicorn self-process killer
  require 'unicorn/worker_killer'

  # Max requests per worker
  use Unicorn::WorkerKiller::MaxRequests, 5_000, 10_000
end

run Rails.application
