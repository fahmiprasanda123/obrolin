require "rails_helper"

RSpec.describe Presence do
  it "stays online until the last connection disconnects" do
    expect(described_class.connect(1, "tab-a")).to be(true)
    expect(described_class.connect(1, "tab-b")).to be(false)
    expect(described_class.online_user_ids([ 1, 2 ])).to eq([ 1 ])

    expect(described_class.disconnect(1, "tab-a")).to be(false)
    expect(described_class.disconnect(1, "tab-b")).to be(true)
    expect(described_class.online_user_ids([ 1 ])).to be_empty
  end

  it "ignores connections that stopped heartbeating" do
    described_class.connect(1, "tab-a")

    travel_to((described_class::STALE_AFTER + 1).seconds.from_now) do
      expect(described_class.online_user_ids([ 1 ])).to be_empty
    end
  end

  it "sets a TTL on the presence key" do
    described_class.connect(1, "tab-a")

    expect(REDIS.with { |r| r.ttl(described_class.key(1)) }).to be_between(1, described_class::KEY_TTL)
  end
end
