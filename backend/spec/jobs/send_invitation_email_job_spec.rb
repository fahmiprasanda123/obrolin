require "rails_helper"

RSpec.describe SendInvitationEmailJob do
  let(:workspace) { create(:workspace) }
  let(:invitation) { workspace.invitations.create!(email: "new@example.com", inviter: workspace.owner) }

  it "emails the invitation link" do
    expect { described_class.perform_now(invitation.id) }.to change { ActionMailer::Base.deliveries.count }.by(1)

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq([ "new@example.com" ])
    expect(mail.text_part.body.to_s).to include(invitation.url)
  end

  it "skips invitations that were already accepted" do
    invitation.update!(accepted_at: Time.current)

    expect { described_class.perform_now(invitation.id) }.not_to(change { ActionMailer::Base.deliveries.count })
  end
end
