# One subscription per chat channel. The client subscribes to every channel
# it has joined (all multiplexed over a single WebSocket) so it can update
# unread badges for channels that are not currently open.
class ConversationChannel < ApplicationCable::Channel
  def subscribed
    @chat_channel = ::Channel.find_by(id: params[:channel_id])
    return reject unless @chat_channel && allowed?

    stream_from @chat_channel.stream_name
    # Tells the client which cable pod it landed on (useful to verify
    # cross-pod broadcasting in Kubernetes).
    transmit({ type: "subscribed", channel_id: @chat_channel.id, server: Socket.gethostname })
  end

  # Typing indicators are ephemeral: broadcast only, never persisted.
  def typing(_data = {})
    return unless @chat_channel.member?(current_user)

    ActionCable.server.broadcast(@chat_channel.stream_name,
                                 { type: "typing", channel_id: @chat_channel.id, user: current_user.public_json })
  end

  private

  def allowed?
    WorkspaceMembership.exists?(workspace_id: @chat_channel.workspace_id, user_id: current_user.id) &&
      @chat_channel.visible_to?(current_user)
  end
end
