require "rails_helper"

RSpec.describe UnreadCounter do
  it "counts other people's messages after last_read_at, per channel" do
    workspace = create(:workspace)
    reader = add_member(workspace)
    writer = add_member(workspace)
    general, random = workspace.channels.order(:name).to_a
    [ general, random ].each { |c| c.channel_memberships.find_or_create_by!(user: writer) }
    memberships = reader.channel_memberships.to_a
    memberships.each { |m| m.update!(last_read_at: 1.hour.ago) }

    create(:message, channel: general, user: writer, created_at: 2.hours.ago) # already read
    create_list(:message, 2, channel: general, user: writer)
    create(:message, channel: general, user: reader)                          # own message
    create(:message, channel: general, user: writer, deleted_at: Time.current)
    create(:message, channel: random, user: writer)

    expect(described_class.counts(reader, memberships)).to eq(general.id => 2, random.id => 1)
  end
end
