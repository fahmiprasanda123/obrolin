require "rails_helper"

RSpec.describe "Invitations API" do
  let(:workspace) { create(:workspace) }
  let(:owner) { workspace.owner }

  it "creates an invitation and enqueues the email job" do
    expect {
      post "/api/v1/workspaces/#{workspace.id}/invitations", params: { email: "new@example.com" },
                                                             headers: auth_headers(owner), as: :json
    }.to have_enqueued_job(SendInvitationEmailJob)

    expect(response).to have_http_status(:created)
    expect(json["url"]).to include("/invite/")
  end

  it "reuses a pending invitation for the same email" do
    2.times do
      post "/api/v1/workspaces/#{workspace.id}/invitations", params: { email: "new@example.com" },
                                                             headers: auth_headers(owner), as: :json
    end

    expect(workspace.invitations.count).to eq(1)
  end

  it "forbids regular members from inviting" do
    member = add_member(workspace)

    post "/api/v1/workspaces/#{workspace.id}/invitations", params: { email: "new@example.com" },
                                                           headers: auth_headers(member), as: :json

    expect(response).to have_http_status(:forbidden)
  end

  describe "accepting" do
    let(:invitation) { workspace.invitations.create!(email: "new@example.com", inviter: owner) }

    it "shows a public preview without authentication" do
      get "/api/v1/invitations/#{invitation.token}"

      expect(response).to have_http_status(:ok)
      expect(json.dig("workspace", "name")).to eq(workspace.name)
      expect(json).not_to have_key("url")
    end

    it "joins the workspace when the email matches" do
      user = create(:user, email: "new@example.com")

      post "/api/v1/invitations/#{invitation.token}/accept", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      expect(json["role"]).to eq("member")
      expect(user.channels.pluck(:name)).to contain_exactly("general", "random")
    end

    it "rejects a different user" do
      post "/api/v1/invitations/#{invitation.token}/accept", headers: auth_headers(create(:user))

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
