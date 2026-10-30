module Api
  module V1
    class WorkspaceMembersController < ApplicationController
      include WorkspaceAccess

      before_action -> { load_workspace!(params[:workspace_id]) }
      before_action :load_target_membership, only: %i[update destroy]

      def index
        memberships = workspace.workspace_memberships.includes(:user).order(:created_at)
        online_ids = Presence.online_user_ids(memberships.map(&:user_id))

        render json: memberships.map { |m| member_json(m, online_ids) }
      end

      # PATCH /workspaces/:workspace_id/members/:id  { role: "admin" }
      # Only the owner can promote/demote, and ownership cannot be transferred here.
      def update
        return render_forbidden("Only the workspace owner can change roles") unless membership.owner?

        role = params.require(:role)
        if role == "owner" || @target.owner?
          return render_forbidden("Ownership cannot be changed")
        end

        if @target.update(role: role)
          render json: member_json(@target, [])
        else
          render_validation_errors(@target)
        end
      end

      # Managers can remove members; anyone can remove themselves (leave).
      def destroy
        leaving = @target.user_id == current_user.id
        return render_forbidden unless leaving || membership.manager?
        return render_forbidden("The owner cannot leave or be removed") if @target.owner?

        WorkspaceMembership.transaction do
          ChannelMembership.joins(:channel)
                           .where(user_id: @target.user_id, channels: { workspace_id: workspace.id })
                           .delete_all
          @target.destroy!
        end
        ActivityLog.record(leaving ? "workspace.left" : "workspace.member_removed",
                           actor: current_user, target: @target.user, workspace_id: workspace.id)
        head :no_content
      end

      private

      # :id is the user id, which is what the frontend has at hand.
      def load_target_membership
        @target = workspace.workspace_memberships.find_by!(user_id: params[:id])
      end

      def member_json(member, online_ids)
        member.user.public_json.merge(role: member.role, online: online_ids.include?(member.user_id))
      end
    end
  end
end
