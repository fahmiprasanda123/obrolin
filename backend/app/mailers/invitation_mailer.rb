class InvitationMailer < ApplicationMailer
  def invite
    @invitation = params[:invitation]
    @workspace = @invitation.workspace
    @inviter = @invitation.inviter
    mail(to: @invitation.email, subject: "#{@inviter.display_name} invited you to #{@workspace.name} on Obrolin")
  end
end
