# Online/offline status kept in Redis.
#
# Each user has a sorted set: member = WebSocket connection id, score = last
# heartbeat (unix seconds). A user is online while at least one connection
# heartbeated recently. Tracking connections (not just a flag) means closing
# one browser tab does not mark a user offline while another tab is open.
#
# The whole key also gets a TTL, so if a cable server crashes without running
# its disconnect callbacks the user drops offline automatically.
module Presence
  KEY_PREFIX = "obrolin:presence:".freeze
  STALE_AFTER = 60 # seconds without heartbeat before a connection is ignored
  KEY_TTL = 90     # seconds before Redis expires the whole key

  module_function

  # Returns true if this connection brought the user online.
  def connect(user_id, connection_id)
    REDIS.with do |redis|
      was_online = online?(redis, user_id)
      touch(redis, user_id, connection_id)
      !was_online
    end
  end

  def heartbeat(user_id, connection_id)
    REDIS.with { |redis| touch(redis, user_id, connection_id) }
  end

  # Returns true if the user has no remaining live connections.
  def disconnect(user_id, connection_id)
    REDIS.with do |redis|
      redis.zrem(key(user_id), connection_id)
      !online?(redis, user_id)
    end
  end

  def online_user_ids(user_ids)
    return [] if user_ids.empty?

    min_score = Time.now.to_i - STALE_AFTER
    counts = REDIS.with do |redis|
      redis.pipelined { |pipe| user_ids.each { |id| pipe.zcount(key(id), min_score, "+inf") } }
    end
    user_ids.zip(counts).select { |_, count| count.to_i.positive? }.map(&:first)
  end

  def online_user?(user_id)
    REDIS.with { |redis| online?(redis, user_id) }
  end

  def key(user_id)
    "#{KEY_PREFIX}#{user_id}"
  end

  def touch(redis, user_id, connection_id)
    now = Time.now.to_i
    redis.multi do |tx|
      tx.zadd(key(user_id), now, connection_id)
      tx.zremrangebyscore(key(user_id), "-inf", now - STALE_AFTER)
      tx.expire(key(user_id), KEY_TTL)
    end
  end

  def online?(redis, user_id)
    redis.zcount(key(user_id), Time.now.to_i - STALE_AFTER, "+inf").positive?
  end
  private_class_method :touch, :online?
end
