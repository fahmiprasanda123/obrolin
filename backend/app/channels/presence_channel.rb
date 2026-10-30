# Streams online/offline events for members of one workspace. The client
# calls `heartbeat` periodically to keep its connection marked as alive.
class PresenceChannel < ApplicationCable::Channel
  def subscribed
    workspace_id = params[:workspace_id].to_i
    return reject unless WorkspaceMembership.exists?(workspace_id: workspace_id, user_id: current_user.id)

    stream_from "presence:workspace:#{workspace_id}"
  end

  def heartbeat(_data = {})
    Presence.heartbeat(current_user.id, connection.connection_id)
  end
end
