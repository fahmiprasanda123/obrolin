require "rails_helper"

RSpec.describe "Messages API" do
  let(:workspace) { create(:workspace) }
  let(:owner) { workspace.owner }
  let(:channel) { workspace.channels.find_by!(name: "general") }
  let(:member) { add_member(workspace, create(:user, username: "budi")) }

  describe "POST /channels/:id/messages" do
    it "creates a message and broadcasts it" do
      expect {
        post "/api/v1/channels/#{channel.id}/messages", params: { message: { body: "Halo semua" } },
                                                        headers: auth_headers(owner), as: :json
      }.to have_broadcasted_to(channel.stream_name).with(hash_including(type: "message.created"))

      expect(response).to have_http_status(:created)
      expect(json).to include("body" => "Halo semua")
      expect(json.dig("user", "id")).to eq(owner.id)
    end

    it "records mentions and enqueues the notification job" do
      member

      expect {
        post "/api/v1/channels/#{channel.id}/messages", params: { message: { body: "cc @budi" } },
                                                        headers: auth_headers(owner), as: :json
      }.to have_enqueued_job(NotifyMentionsJob)

      expect(json["mentions"]).to eq([ member.id ])
    end

    it "requires channel membership" do
      other = create(:channel, workspace: workspace)

      post "/api/v1/channels/#{other.id}/messages", params: { message: { body: "hi" } },
                                                    headers: auth_headers(member), as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "creates thread replies and bumps the parent's reply count" do
      parent = create(:message, channel: channel, user: owner)

      post "/api/v1/channels/#{channel.id}/messages",
           params: { message: { body: "reply", parent_message_id: parent.id.to_s } },
           headers: auth_headers(owner), as: :json

      expect(response).to have_http_status(:created)
      expect(parent.reload.reply_count).to eq(1)

      get "/api/v1/messages/#{parent.id}/replies", headers: auth_headers(owner)
      expect(json["replies"].map { |r| r["body"] }).to eq([ "reply" ])
    end
  end

  describe "GET /channels/:id/messages" do
    it "returns a page of top-level messages with a cursor" do
      messages = Array.new(3) { |i| create(:message, channel: channel, user: owner, created_at: i.minutes.ago) }
      create(:message, channel: channel, user: owner, parent_message_id: messages.first.id)

      get "/api/v1/channels/#{channel.id}/messages", params: { limit: 2 }, headers: auth_headers(owner)

      expect(json["messages"].map { |m| m["id"] }).to eq(messages[0..1].map { |m| m.id.to_s })
      expect(json["next_cursor"]).to eq(messages[1].id.to_s)

      get "/api/v1/channels/#{channel.id}/messages", params: { limit: 2, before: json["next_cursor"] },
                                                     headers: auth_headers(owner)
      expect(json["messages"].map { |m| m["id"] }).to eq([ messages[2].id.to_s ])
      expect(json["next_cursor"]).to be_nil
    end

    it "hides private channel history from non-members" do
      secret = create(:channel, workspace: workspace, is_private: true)

      get "/api/v1/channels/#{secret.id}/messages", headers: auth_headers(member)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "editing and deleting" do
    let(:message) { create(:message, channel: channel, user: member) }

    it "lets the author edit and marks it edited" do
      patch "/api/v1/messages/#{message.id}", params: { message: { body: "fixed" } },
                                              headers: auth_headers(member), as: :json

      expect(json).to include("body" => "fixed")
      expect(json["edited_at"]).to be_present
    end

    it "forbids editing someone else's message" do
      patch "/api/v1/messages/#{message.id}", params: { message: { body: "hacked" } },
                                              headers: auth_headers(owner), as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "soft-deletes (admins may delete any message)" do
      expect {
        delete "/api/v1/messages/#{message.id}", headers: auth_headers(owner)
      }.to have_broadcasted_to(channel.stream_name).with(hash_including(type: "message.deleted"))

      expect(message.reload.deleted_at).to be_present
      expect(Message.where(_id: message.id).count).to eq(1)
    end
  end

  describe "reactions" do
    it "toggles a reaction" do
      message = create(:message, channel: channel, user: owner)

      post "/api/v1/messages/#{message.id}/reactions", params: { emoji: "🎉" }, headers: auth_headers(owner), as: :json
      expect(json["reactions"]).to eq([ { "emoji" => "🎉", "user_ids" => [ owner.id ], "count" => 1 } ])

      post "/api/v1/messages/#{message.id}/reactions", params: { emoji: "🎉" }, headers: auth_headers(owner), as: :json
      expect(json["reactions"]).to be_empty
    end
  end

  describe "GET /channels/:id/messages/search" do
    it "finds messages by text within the channel" do
      create(:message, channel: channel, user: owner, body: "Deploy finished successfully")
      create(:message, channel: channel, user: owner, body: "Lunch at noon?")
      create(:message, channel: workspace.channels.find_by!(name: "random"), user: owner, body: "deploy elsewhere")

      get "/api/v1/channels/#{channel.id}/messages/search", params: { q: "deploy" }, headers: auth_headers(owner)

      expect(json["messages"].map { |m| m["body"] }).to eq([ "Deploy finished successfully" ])
    end
  end
end
