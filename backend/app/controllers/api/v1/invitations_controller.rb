module Api
  module V1
    class InvitationsController < ApplicationController
      include WorkspaceAccess

      before_action -> { load_workspace!(params[:workspace_id]) }
      before_action :require_manager!

      def index
        invitations = workspace.invitations.pending.includes(:inviter, :workspace).order(created_at: :desc)
        render json: invitations.map { |i| InvitationSerializer.render(i, include_url: true) }
      end

      # Re-inviting the same email refreshes the existing pending invitation
      # instead of creating duplicates.
      def create
        email = params.require(:email).to_s.strip.downcase
        invitation = workspace.invitations.pending.find_by(email: email) ||
                     workspace.invitations.new(email: email, inviter: current_user)
        invitation.expires_at = Invitation::TTL.from_now

        if invitation.save
          SendInvitationEmailJob.perform_later(invitation.id)
          ActivityLog.record("invitation.sent", actor: current_user, target: invitation,
                                                workspace_id: workspace.id, email: email)
          render json: InvitationSerializer.render(invitation, include_url: true), status: :created
        else
          render_validation_errors(invitation)
        end
      end

      def destroy
        workspace.invitations.find(params[:id]).destroy!
        head :no_content
      end
    end
  end
end
