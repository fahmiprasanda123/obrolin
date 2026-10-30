require "rails_helper"

RSpec.describe User do
  subject { build(:user) }

  it { is_expected.to validate_presence_of(:display_name) }
  it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
  it { is_expected.to validate_uniqueness_of(:username).case_insensitive }
  it { is_expected.to have_secure_password }

  it "normalizes email and username to lowercase" do
    user = create(:user, email: "  Alice@Example.COM ", username: "Alice_01")

    expect(user.email).to eq("alice@example.com")
    expect(user.username).to eq("alice_01")
  end

  it "rejects usernames with spaces or symbols" do
    user = build(:user, username: "bad name!")

    expect(user).not_to be_valid
    expect(user.errors[:username]).to be_present
  end

  it "requires passwords of at least 8 characters" do
    expect(build(:user, password: "short")).not_to be_valid
  end

  it "never exposes the password digest in JSON" do
    expect(create(:user).as_json.keys).not_to include(:password_digest)
  end
end
