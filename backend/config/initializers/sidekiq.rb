sidekiq_redis = { url: ENV.fetch("REDIS_SIDEKIQ_URL", "redis://localhost:6379/2") }

Sidekiq.configure_server do |config|
  config.redis = sidekiq_redis

  # Liveness signal for Kubernetes: the probe checks this file's age.
  # :beat fires on every heartbeat (~10s); :heartbeat would fire only once.
  config.on(:beat) { FileUtils.touch("/tmp/sidekiq_alive") }
end

Sidekiq.configure_client do |config|
  config.redis = sidekiq_redis
end
