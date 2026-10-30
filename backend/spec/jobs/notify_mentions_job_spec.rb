require "rails_helper"

RSpec.describe NotifyMentionsJob do
  let(:workspace) { create(:workspace) }
  let(:author) { workspace.owner }
  let(:budi) { add_member(workspace, create(:user, username: "budi")) }
  let(:general) { workspace.channels.find_by!(name: "general") }

  it "notifies mentioned users in real time and emails them when offline" do
    message = create(:message, channel: general, user: author, body: "hi @budi", mentions: [ budi.id ])

    expect {
      described_class.perform_now(message.id.to_s, [ budi.id ])
    }.to have_broadcasted_to(NotificationsChannel.broadcasting_for(budi)).with(hash_including(type: "mention"))
      .and change { ActionMailer::Base.deliveries.count }.by(1)

    expect(ActionMailer::Base.deliveries.last.to).to eq([ budi.email ])
  end

  it "does not email users who are online" do
    Presence.connect(budi.id, "conn")
    message = create(:message, channel: general, user: author, body: "hi @budi", mentions: [ budi.id ])

    expect { described_class.perform_now(message.id.to_s, [ budi.id ]) }
      .not_to(change { ActionMailer::Base.deliveries.count })
  end

  it "skips users who cannot see a private channel" do
    secret = create(:channel, workspace: workspace, is_private: true)
    message = create(:message, channel: secret, user: author, body: "hi @budi", mentions: [ budi.id ])

    expect { described_class.perform_now(message.id.to_s, [ budi.id ]) }
      .not_to have_broadcasted_to(NotificationsChannel.broadcasting_for(budi))
  end
end
