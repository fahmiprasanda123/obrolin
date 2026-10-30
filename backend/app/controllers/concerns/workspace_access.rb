# Loads workspaces/channels through the current user's memberships, so a
# non-member gets 404 (we do not reveal that the resource exists).
module WorkspaceAccess
  extend ActiveSupport::Concern

  private

  attr_reader :workspace, :membership, :channel

  def load_workspace!(id)
    @workspace = current_user.workspaces.find(id)
    @membership = @workspace.membership_for(current_user)
  end

  def load_channel!(id)
    @channel = Channel.find(id)
    @workspace = @channel.workspace
    @membership = @workspace.membership_for(current_user)
    raise ActiveRecord::RecordNotFound unless @membership && @channel.visible_to?(current_user)
  end

  def require_manager!
    render_forbidden("Only workspace owners and admins can do that") unless membership&.manager?
  end

  def require_channel_member!
    render_forbidden("Join this channel first") unless channel.member?(current_user)
  end
end
