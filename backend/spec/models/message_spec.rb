require "rails_helper"

RSpec.describe Message do
  let(:channel) { create(:channel) }
  let(:author) { channel.created_by }

  it "extracts @mentions but ignores emails" do
    expect(described_class.extract_usernames("hi @Budi and @citra_1, mail a@b.com @budi"))
      .to eq(%w[budi citra_1])
  end

  it "resolves mentions to members of the workspace only" do
    budi = add_member(channel.workspace, create(:user, username: "budi"))
    create(:user, username: "outsider")

    message = build(:message, channel: channel, body: "hey @budi and @outsider")
    message.assign_mentions

    expect(message.mentions).to eq([ budi.id ])
  end

  describe ".page" do
    it "paginates newest first with a cursor" do
      messages = Array.new(5) { |i| create(:message, channel: channel, created_at: i.minutes.ago) }

      first_page, cursor = described_class.page(described_class.history_for(channel.id), limit: 2)
      second_page, cursor2 = described_class.page(described_class.history_for(channel.id), before: cursor, limit: 2)
      last_page, cursor3 = described_class.page(described_class.history_for(channel.id), before: cursor2, limit: 2)

      expect(first_page).to eq(messages[0..1])
      expect(second_page).to eq(messages[2..3])
      expect(last_page).to eq([ messages[4] ])
      expect(cursor3).to be_nil
    end

    it "is stable when several messages share a timestamp" do
      at = Time.current.change(usec: 0)
      messages = Array.new(3) { create(:message, channel: channel, created_at: at) }

      page1, cursor = described_class.page(described_class.history_for(channel.id), limit: 2)
      page2, = described_class.page(described_class.history_for(channel.id), before: cursor, limit: 2)

      expect((page1 + page2).map(&:id)).to match_array(messages.map(&:id))
    end
  end

  describe ".history_for" do
    it "hides deleted messages unless they have replies" do
      plain = create(:message, channel: channel, deleted_at: Time.current)
      with_replies = create(:message, channel: channel, deleted_at: Time.current, reply_count: 1)
      reply = create(:message, channel: channel, parent_message_id: with_replies.id)

      ids = described_class.history_for(channel.id).pluck(:_id)

      expect(ids).to include(with_replies.id)
      expect(ids).not_to include(plain.id, reply.id)
    end
  end

  describe "#toggle_reaction!" do
    it "adds and removes a user's reaction" do
      message = create(:message, channel: channel)

      message.toggle_reaction!("👍", 1)
      message.toggle_reaction!("👍", 2)
      expect(message.reload.reactions.first.user_ids).to eq([ 1, 2 ])

      message.toggle_reaction!("👍", 1)
      message.toggle_reaction!("👍", 2)
      expect(message.reload.reactions).to be_empty
    end
  end
end
