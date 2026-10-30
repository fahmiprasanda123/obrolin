require "rails_helper"

RSpec.describe "Channels API" do
  let(:workspace) { create(:workspace) }
  let(:owner) { workspace.owner }
  let!(:member) { add_member(workspace) }

  describe "GET /workspaces/:id/channels" do
    it "lists visible channels with membership and unread counts" do
      secret = create(:channel, workspace: workspace, name: "secret", is_private: true)
      design = create(:channel, workspace: workspace, name: "design")
      general = workspace.channels.find_by(name: "general")
      create(:message, channel: general, user: owner)

      get "/api/v1/workspaces/#{workspace.id}/channels", headers: auth_headers(member)

      by_name = json.index_by { |c| c["name"] }
      expect(by_name.keys).to contain_exactly("general", "random", "design")
      expect(by_name).not_to have_key(secret.name)
      expect(by_name["general"]).to include("is_member" => true, "unread_count" => 1)
      expect(by_name[design.name]).to include("is_member" => false, "unread_count" => 0)
    end
  end

  describe "POST /workspaces/:id/channels" do
    it "creates a private channel with selected members" do
      post "/api/v1/workspaces/#{workspace.id}/channels",
           params: { channel: { name: "Core Team", is_private: true }, member_ids: [ member.id ] },
           headers: auth_headers(owner), as: :json

      expect(response).to have_http_status(:created)
      expect(json).to include("name" => "core-team", "is_private" => true, "member_count" => 2)
    end

    it "returns validation errors for duplicate names" do
      post "/api/v1/workspaces/#{workspace.id}/channels", params: { channel: { name: "general" } },
                                                          headers: auth_headers(owner), as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "join / leave / read" do
    let(:channel) { create(:channel, workspace: workspace) }

    it "joins and leaves a public channel" do
      post "/api/v1/channels/#{channel.id}/join", headers: auth_headers(member)
      expect(json["is_member"]).to be(true)

      delete "/api/v1/channels/#{channel.id}/leave", headers: auth_headers(member)
      expect(channel.member?(member)).to be(false)
    end

    it "cannot see or join a private channel" do
      secret = create(:channel, workspace: workspace, is_private: true)

      post "/api/v1/channels/#{secret.id}/join", headers: auth_headers(member)

      expect(response).to have_http_status(:not_found)
    end

    it "marks a channel as read" do
      channel.channel_memberships.create!(user: member, last_read_at: 1.day.ago)

      post "/api/v1/channels/#{channel.id}/read", headers: auth_headers(member)

      expect(channel.channel_memberships.find_by(user: member).last_read_at).to be_within(5.seconds).of(Time.current)
    end
  end

  describe "members" do
    it "lets a member add a workspace member to a private channel" do
      secret = create(:channel, workspace: workspace, is_private: true)

      post "/api/v1/channels/#{secret.id}/members", params: { user_id: member.id }, headers: auth_headers(owner), as: :json

      expect(response).to have_http_status(:created)
      get "/api/v1/channels/#{secret.id}/members", headers: auth_headers(member)
      expect(json.map { |u| u["id"] }).to contain_exactly(owner.id, member.id)
    end
  end
end
