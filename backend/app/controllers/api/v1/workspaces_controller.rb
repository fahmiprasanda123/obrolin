module Api
  module V1
    class WorkspacesController < ApplicationController
      include WorkspaceAccess

      before_action -> { load_workspace!(params[:id]) }, only: %i[show update]
      before_action :require_manager!, only: :update

      def index
        memberships = current_user.workspace_memberships.includes(:workspace).order(:created_at)
        render json: memberships.map { |m| WorkspaceSerializer.render(m.workspace, membership: m) }
      end

      def show
        render json: WorkspaceSerializer.render(workspace, membership: membership)
      end

      def create
        new_workspace = Workspace.create_with_owner!(owner: current_user, name: workspace_params[:name])
        ActivityLog.record("workspace.created", actor: current_user, target: new_workspace, workspace_id: new_workspace.id)
        render json: WorkspaceSerializer.render(new_workspace, membership: new_workspace.membership_for(current_user)),
               status: :created
      rescue ActiveRecord::RecordInvalid => e
        render_validation_errors(e.record)
      end

      def update
        if workspace.update(workspace_params)
          render json: WorkspaceSerializer.render(workspace, membership: membership)
        else
          render_validation_errors(workspace)
        end
      end

      private

      def workspace_params
        params.require(:workspace).permit(:name)
      end
    end
  end
end
