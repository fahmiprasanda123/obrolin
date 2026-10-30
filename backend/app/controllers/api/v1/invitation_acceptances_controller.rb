module Api
  module V1
    # Public preview + accept endpoints for the link in the invitation email.
    class InvitationAcceptancesController < ApplicationController
      skip_before_action :authenticate_user!, only: :show
      before_action :load_invitation

      # GET /api/v1/invitations/:token  (no auth: shown before login/register)
      def show
        render json: InvitationSerializer.render(@invitation)
      end

      # POST /api/v1/invitations/:token/accept
      def create
        @invitation.accept!(current_user)
        ActivityLog.record("workspace.joined", actor: current_user, target: @invitation.workspace,
                                               workspace_id: @invitation.workspace_id, via: "invitation")
        workspace = @invitation.workspace
        render json: WorkspaceSerializer.render(workspace, membership: workspace.membership_for(current_user))
      rescue Invitation::NotAcceptable => e
        render json: { error: e.message }, status: :unprocessable_content
      end

      private

      def load_invitation
        @invitation = Invitation.includes(:workspace, :inviter).find_by!(token: params[:token])
      end
    end
  end
end
