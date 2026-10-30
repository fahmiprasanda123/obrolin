require "rails_helper"

RSpec.describe Invitation do
  let(:workspace) { create(:workspace) }
  let(:invitation) { workspace.invitations.create!(email: "New@Example.com", inviter: workspace.owner) }

  it "normalizes the email and generates a token and expiry" do
    expect(invitation.email).to eq("new@example.com")
    expect(invitation.token.length).to eq(32)
    expect(invitation.expires_at).to be_within(1.minute).of(7.days.from_now)
  end

  it "rejects inviting an existing member" do
    member = add_member(workspace)

    expect(workspace.invitations.build(email: member.email, inviter: workspace.owner)).not_to be_valid
  end

  describe "#accept!" do
    it "adds the user to the workspace" do
      user = create(:user, email: "new@example.com")

      invitation.accept!(user)

      expect(workspace.membership_for(user)).to be_member
      expect(invitation.reload).to be_accepted
    end

    it "refuses a user with a different email" do
      expect { invitation.accept!(create(:user)) }.to raise_error(Invitation::NotAcceptable, /different email/)
    end

    it "refuses expired and used invitations" do
      user = create(:user, email: "new@example.com")
      invitation.update!(expires_at: 1.minute.ago)
      expect { invitation.accept!(user) }.to raise_error(Invitation::NotAcceptable, /expired/)

      invitation.update!(expires_at: 1.day.from_now, accepted_at: Time.current)
      expect { invitation.accept!(user) }.to raise_error(Invitation::NotAcceptable, /already/)
    end
  end
end
