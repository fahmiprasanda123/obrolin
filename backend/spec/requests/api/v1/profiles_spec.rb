require "rails_helper"

RSpec.describe "Profile API" do
  let(:user) { create(:user, display_name: "Old Name", password: "password123") }

  describe "GET /api/v1/me" do
    it "returns the current user" do
      get "/api/v1/me", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      expect(json["id"]).to eq(user.id)
    end

    it "requires a token" do
      get "/api/v1/me"

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects a malformed token" do
      get "/api/v1/me", headers: { "Authorization" => "Bearer not-a-jwt" }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/me" do
    it "updates the display name" do
      patch "/api/v1/me", params: { user: { display_name: "New Name" } }, headers: auth_headers(user), as: :json

      expect(response).to have_http_status(:ok)
      expect(user.reload.display_name).to eq("New Name")
    end

    it "changes the password only with the correct current password" do
      patch "/api/v1/me", params: { user: { password: "newpassword1", current_password: "wrong" } },
                          headers: auth_headers(user), as: :json
      expect(response).to have_http_status(:unprocessable_content)

      patch "/api/v1/me", params: { user: { password: "newpassword1", current_password: "password123" } },
                          headers: auth_headers(user), as: :json
      expect(response).to have_http_status(:ok)
      expect(user.reload.authenticate("newpassword1")).to be_truthy
    end
  end
end
