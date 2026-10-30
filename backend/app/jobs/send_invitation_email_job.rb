class SendInvitationEmailJob < ApplicationJob
  queue_as :mailers

  def perform(invitation_id)
    invitation = Invitation.includes(:workspace, :inviter).find_by(id: invitation_id)
    return unless invitation&.pending? # revoked or used before the job ran

    InvitationMailer.with(invitation: invitation).invite.deliver_now
  end
end
