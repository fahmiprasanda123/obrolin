require "rails_helper"

RSpec.describe JsonWebToken do
  it "round-trips the user id" do
    token = described_class.encode(42)

    expect(described_class.decode(token)["sub"]).to eq(42)
  end

  it "rejects expired tokens" do
    token = described_class.encode(42, ttl: 1.minute)

    travel_to(2.minutes.from_now) do
      expect { described_class.decode(token) }.to raise_error(described_class::InvalidToken)
    end
  end

  it "rejects tampered tokens" do
    header, _payload, signature = described_class.encode(42).split(".")
    forged = Base64.urlsafe_encode64({ sub: 1, jti: "x", exp: 1.hour.from_now.to_i }.to_json, padding: false)

    expect { described_class.decode([ header, forged, signature ].join(".")) }
      .to raise_error(described_class::InvalidToken)
  end

  it "rejects revoked tokens and expires the denylist entry with the token" do
    token = described_class.encode(42, ttl: 10.minutes)
    payload = described_class.decode(token)

    described_class.revoke(payload)

    expect { described_class.decode(token) }.to raise_error(described_class::InvalidToken, /revoked/)
    ttl = REDIS.with { |r| r.ttl(described_class::DENYLIST_PREFIX + payload["jti"]) }
    expect(ttl).to be_between(1, 600)
  end
end
