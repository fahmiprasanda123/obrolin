class InvitationSerializer
  # The URL is included for workspace managers so they can share the link
  # directly (handy when email delivery is not configured).
  def self.render(invitation, include_url: false)
    data = {
      id: invitation.id,
      email: invitation.email,
      workspace: { id: invitation.workspace_id, name: invitation.workspace.name },
      inviter: invitation.inviter.public_json,
      expires_at: invitation.expires_at,
      accepted_at: invitation.accepted_at,
      status: invitation.accepted? ? "accepted" : (invitation.expired? ? "expired" : "pending")
    }
    data[:url] = invitation.url if include_url
    data
  end
end
