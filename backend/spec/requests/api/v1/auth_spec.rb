require "rails_helper"

RSpec.describe "Auth API" do
  describe "POST /api/v1/auth/register" do
    let(:params) do
      { user: { email: "budi@example.com", username: "budi", display_name: "Budi", password: "password123" } }
    end

    it "creates a user and returns a token" do
      expect { post "/api/v1/auth/register", params: params, as: :json }.to change(User, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json["token"]).to be_present
      expect(json["user"]).to include("username" => "budi", "email" => "budi@example.com")
      expect(json["user"]).not_to have_key("password_digest")
    end

    it "returns validation errors" do
      create(:user, email: "budi@example.com")

      post "/api/v1/auth/register", params: params, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to have_key("email")
    end
  end

  describe "POST /api/v1/auth/login" do
    let!(:user) { create(:user, email: "siti@example.com", username: "siti", password: "password123") }

    it "logs in with email" do
      post "/api/v1/auth/login", params: { login: "SITI@example.com", password: "password123" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json.dig("user", "id")).to eq(user.id)
    end

    it "logs in with username" do
      post "/api/v1/auth/login", params: { login: "siti", password: "password123" }, as: :json

      expect(response).to have_http_status(:ok)
    end

    it "rejects a wrong password" do
      post "/api/v1/auth/login", params: { login: "siti", password: "nope" }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/auth/logout" do
    it "revokes the token so it can no longer be used" do
      user = create(:user)
      headers = auth_headers(user)

      delete "/api/v1/auth/logout", headers: headers
      expect(response).to have_http_status(:no_content)

      get "/api/v1/me", headers: headers
      expect(response).to have_http_status(:unauthorized)
    end
  end
end

RSpec.describe "Auth rate limiting" do
  it "blocks an IP after 10 login attempts within 3 minutes" do
    create(:user, username: "siti", password: "password123")

    10.times { post "/api/v1/auth/login", params: { login: "siti", password: "wrong" }, as: :json }
    expect(response).to have_http_status(:unauthorized)

    post "/api/v1/auth/login", params: { login: "siti", password: "password123" }, as: :json
    expect(response).to have_http_status(:too_many_requests)
    expect(response.parsed_body["error"]).to match(/Too many attempts/)

    travel_to(4.minutes.from_now) do
      post "/api/v1/auth/login", params: { login: "siti", password: "password123" }, as: :json
      expect(response).to have_http_status(:ok)
    end
  end
end
