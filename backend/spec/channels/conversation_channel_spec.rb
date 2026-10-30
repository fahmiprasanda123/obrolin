require "rails_helper"

RSpec.describe ConversationChannel do
  let(:workspace) { create(:workspace) }
  let(:member) { add_member(workspace) }
  let(:general) { workspace.channels.find_by!(name: "general") }

  before { stub_connection current_user: member, connection_id: "conn-1" }

  it "streams a channel the user can see" do
    subscribe(channel_id: general.id)

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from(general.stream_name)
  end

  it "rejects private channels the user is not in" do
    secret = create(:channel, workspace: workspace, is_private: true)

    subscribe(channel_id: secret.id)

    expect(subscription).to be_rejected
  end

  it "broadcasts typing without persisting anything" do
    subscribe(channel_id: general.id)

    expect { perform :typing }
      .to have_broadcasted_to(general.stream_name).with(hash_including(type: "typing"))
    expect(Message.count).to eq(0)
  end
end
