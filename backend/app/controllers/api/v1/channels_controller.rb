module Api
  module V1
    class ChannelsController < ApplicationController
      include WorkspaceAccess

      before_action -> { load_workspace!(params[:workspace_id]) }, only: %i[index create]
      before_action -> { load_channel!(params[:id]) }, only: %i[show update join leave read]

      # Visible channels in a workspace, with the current user's membership
      # state and unread counts for the channels they joined.
      def index
        channels = workspace.channels.visible_to(current_user).order(:name).to_a
        my_memberships = current_user.channel_memberships.where(channel_id: channels.map(&:id)).index_by(&:channel_id)
        member_counts = ChannelMembership.where(channel_id: channels.map(&:id)).group(:channel_id).count
        unread = UnreadCounter.counts(current_user, my_memberships.values)

        render json: channels.map { |c|
          ChannelSerializer.render(c, membership: my_memberships[c.id], member_count: member_counts[c.id] || 0,
                                      unread_count: unread[c.id] || 0)
        }
      end

      def show
        render json: serialize(channel)
      end

      # POST /workspaces/:workspace_id/channels
      # { channel: { name, description, is_private }, member_ids: [..] }
      def create
        new_channel = workspace.channels.new(channel_params.merge(created_by: current_user))

        Channel.transaction do
          new_channel.save!
          new_channel.channel_memberships.create!(user: current_user)
          invitee_ids = Array(params[:member_ids]).map(&:to_i) - [ current_user.id ]
          workspace.members.where(id: invitee_ids).find_each do |user|
            new_channel.channel_memberships.create!(user: user)
          end
        end

        ActivityLog.record("channel.created", actor: current_user, target: new_channel,
                                              workspace_id: workspace.id, private: new_channel.is_private)
        render json: serialize(new_channel), status: :created
      rescue ActiveRecord::RecordInvalid => e
        render_validation_errors(e.record)
      end

      def update
        unless channel.created_by_id == current_user.id || membership.manager?
          return render_forbidden("Only the channel creator or workspace admins can edit this channel")
        end

        if channel.update(channel_params.except(:is_private))
          broadcast_channel_event("channel.updated")
          render json: serialize(channel)
        else
          render_validation_errors(channel)
        end
      end

      # Only public channels can be joined freely; private ones need an invite
      # from an existing member (see ChannelMembersController#create).
      def join
        return render_forbidden("Private channels require an invitation") if channel.is_private?

        channel.channel_memberships.find_or_create_by!(user: current_user)
        ActivityLog.record("channel.joined", actor: current_user, target: channel, workspace_id: workspace.id)
        broadcast_channel_event("member.joined", user: current_user.public_json)
        render json: serialize(channel)
      end

      def leave
        channel.channel_memberships.where(user: current_user).destroy_all
        ActivityLog.record("channel.left", actor: current_user, target: channel, workspace_id: workspace.id)
        broadcast_channel_event("member.left", user: current_user.public_json)
        head :no_content
      end

      # POST /channels/:id/read : marks everything up to now as read.
      def read
        my_membership = channel.channel_memberships.find_by(user: current_user)
        return render_forbidden("Join this channel first") unless my_membership

        my_membership.update!(last_read_at: Time.current)
        render json: { last_read_at: my_membership.last_read_at }
      end

      private

      def channel_params
        params.require(:channel).permit(:name, :description, :is_private)
      end

      def serialize(record)
        my_membership = record.channel_memberships.find_by(user: current_user)
        ChannelSerializer.render(record, membership: my_membership, member_count: record.channel_memberships.count,
                                         unread_count: UnreadCounter.counts(current_user, [ my_membership ].compact)[record.id] || 0)
      end

      def broadcast_channel_event(type, **payload)
        ActionCable.server.broadcast(channel.stream_name, { type: type, channel_id: channel.id, **payload })
      end
    end
  end
end
