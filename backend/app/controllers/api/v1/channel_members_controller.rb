module Api
  module V1
    class ChannelMembersController < ApplicationController
      include WorkspaceAccess

      before_action -> { load_channel!(params[:channel_id]) }

      def index
        users = channel.members.order(:username)
        online_ids = Presence.online_user_ids(users.map(&:id))
        render json: users.map { |u| u.public_json.merge(online: online_ids.include?(u.id)) }
      end

      # POST /channels/:channel_id/members  { user_id: 3 }
      # Any channel member may add another workspace member.
      def create
        return render_forbidden("Join this channel first") unless channel.member?(current_user)

        user = workspace.members.find(params.require(:user_id))
        channel.channel_memberships.find_or_create_by!(user: user)
        ActivityLog.record("channel.member_added", actor: current_user, target: channel,
                                                   workspace_id: workspace.id, user_id: user.id)
        ActionCable.server.broadcast(channel.stream_name,
                                     { type: "member.joined", channel_id: channel.id, user: user.public_json })
        render json: user.public_json, status: :created
      end
    end
  end
end
