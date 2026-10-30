# A shared Redis connection pool for application-level keys (JWT denylist,
# presence, rate limiting). ActionCable, Sidekiq and the cache store manage
# their own connections.
require "connection_pool"

REDIS = ConnectionPool.new(size: ENV.fetch("RAILS_MAX_THREADS", 5).to_i, timeout: 3) do
  Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
end
