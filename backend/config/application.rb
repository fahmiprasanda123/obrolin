require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "action_cable/engine"

Bundler.require(*Rails.groups)

# When running on the host, read the shared ../.env file. In containers the
# variables come from Docker Compose / Kubernetes, and dotenv is not installed.
if defined?(Dotenv)
  Dotenv.load(File.expand_path("../../.env", __dir__))
end

module Obrolin
  class Application < Rails::Application
    config.load_defaults 8.0
    config.autoload_lib(ignore: %w[assets tasks])

    config.api_only = true

    # Mongoid registers itself as the default ORM for generators; keep
    # ActiveRecord as the default and opt into Mongoid models explicitly.
    config.generators do |g|
      g.orm :active_record
      g.test_framework :rspec
    end

    # Background jobs run in Sidekiq (backed by Redis), not Solid Queue.
    config.active_job.queue_adapter = :sidekiq

    config.cache_store = :redis_cache_store, {
      url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
      namespace: "obrolin:cache"
    }

    # The cable server is mounted at /cable in the same app; in Kubernetes a
    # dedicated deployment serves it (see k8s/).
    config.action_cable.mount_path = "/cable"
    config.action_cable.allowed_request_origins =
      ENV.fetch("ALLOWED_ORIGINS", "http://localhost:5173").split(",").map(&:strip)
  end
end
