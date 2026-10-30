# Issues and verifies the JWT access tokens used by both the REST API
# (Authorization: Bearer <token>) and ActionCable (/cable?token=<token>).
#
# JWTs are stateless, so "logout" cannot delete them. Instead each token has
# a unique jti; logging out stores that jti in Redis until the token would
# have expired anyway, and decode rejects any denylisted jti.
class JsonWebToken
  class InvalidToken < StandardError; end

  ALGORITHM = "HS256".freeze
  DENYLIST_PREFIX = "obrolin:jwt:denylist:".freeze

  class << self
    def encode(user_id, ttl: default_ttl)
      now = Time.current.to_i
      payload = { sub: user_id, jti: SecureRandom.uuid, iat: now, exp: now + ttl.to_i }
      JWT.encode(payload, secret, ALGORITHM)
    end

    # Returns the payload hash, or raises InvalidToken.
    def decode(token)
      payload, = JWT.decode(token, secret, true, algorithm: ALGORITHM, required_claims: %w[sub jti exp])
      raise InvalidToken, "Token has been revoked" if revoked?(payload["jti"])

      payload
    rescue JWT::DecodeError => e
      raise InvalidToken, e.message
    end

    def revoke(payload)
      remaining = payload["exp"].to_i - Time.current.to_i
      return if remaining <= 0

      REDIS.with { |redis| redis.set(DENYLIST_PREFIX + payload["jti"], 1, ex: remaining) }
    end

    def revoked?(jti)
      REDIS.with { |redis| redis.exists?(DENYLIST_PREFIX + jti) }
    end

    private

    def secret
      ENV.fetch("JWT_SECRET") { Rails.application.secret_key_base }
    end

    def default_ttl
      ENV.fetch("JWT_TTL_MINUTES", 1440).to_i.minutes
    end
  end
end
