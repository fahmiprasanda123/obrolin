require "rails_helper"

RSpec.describe ApplicationCable::Connection, type: :channel do
  let(:user) { create(:user) }

  it "connects with a valid JWT and marks the user online" do
    connect "/cable?token=#{JsonWebToken.encode(user.id)}"

    expect(connection.current_user).to eq(user)
    expect(Presence.online_user_ids([ user.id ])).to eq([ user.id ])
  end

  it "rejects missing or invalid tokens" do
    expect { connect "/cable" }.to have_rejected_connection
    expect { connect "/cable?token=garbage" }.to have_rejected_connection
  end

  it "marks the user offline on disconnect" do
    connect "/cable?token=#{JsonWebToken.encode(user.id)}"
    disconnect

    expect(Presence.online_user_ids([ user.id ])).to be_empty
  end
end
