require "rails_helper"

RSpec.describe "Workspaces API" do
  let(:user) { create(:user) }

  it "creates a workspace owned by the current user" do
    post "/api/v1/workspaces", params: { workspace: { name: "Tim Obrolin" } }, headers: auth_headers(user), as: :json

    expect(response).to have_http_status(:created)
    expect(json).to include("name" => "Tim Obrolin", "slug" => "tim-obrolin", "role" => "owner")
    expect(ActivityLog.where(action: "workspace.created").count).to eq(1)
  end

  it "lists only the user's workspaces" do
    mine = create(:workspace, owner: user)
    create(:workspace)

    get "/api/v1/workspaces", headers: auth_headers(user)

    expect(json.map { |w| w["id"] }).to eq([ mine.id ])
  end

  it "returns 404 for a workspace the user does not belong to" do
    get "/api/v1/workspaces/#{create(:workspace).id}", headers: auth_headers(user)

    expect(response).to have_http_status(:not_found)
  end

  it "lets only managers rename the workspace" do
    workspace = create(:workspace)
    member = add_member(workspace)

    patch "/api/v1/workspaces/#{workspace.id}", params: { workspace: { name: "X" } }, headers: auth_headers(member), as: :json
    expect(response).to have_http_status(:forbidden)

    patch "/api/v1/workspaces/#{workspace.id}", params: { workspace: { name: "X" } },
                                                headers: auth_headers(workspace.owner), as: :json
    expect(response).to have_http_status(:ok)
  end

  describe "members" do
    let(:workspace) { create(:workspace) }
    let!(:member) { add_member(workspace) }

    it "lists members with role and presence" do
      Presence.connect(member.id, "conn-1")

      get "/api/v1/workspaces/#{workspace.id}/members", headers: auth_headers(member)

      row = json.find { |m| m["id"] == member.id }
      expect(row).to include("role" => "member", "online" => true)
      expect(row).not_to have_key("email")
    end

    it "lets the owner promote a member to admin" do
      patch "/api/v1/workspaces/#{workspace.id}/members/#{member.id}", params: { role: "admin" },
                                                                       headers: auth_headers(workspace.owner), as: :json

      expect(response).to have_http_status(:ok)
      expect(workspace.membership_for(member)).to be_admin
    end

    it "lets a member leave, removing their channel memberships" do
      delete "/api/v1/workspaces/#{workspace.id}/members/#{member.id}", headers: auth_headers(member)

      expect(response).to have_http_status(:no_content)
      expect(member.channel_memberships).to be_empty
    end

    it "does not let the owner be removed" do
      admin = add_member(workspace, role: :admin)

      delete "/api/v1/workspaces/#{workspace.id}/members/#{workspace.owner_id}", headers: auth_headers(admin)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
