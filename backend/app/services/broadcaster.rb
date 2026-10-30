# All WebSocket broadcasts go through here. ActionCable.server.broadcast
# publishes to Redis, so it works from any process (API pod, Sidekiq worker)
# and reaches subscribers on every cable pod.
module Broadcaster
  module_function

  def message(type, message, **extra)
    ActionCable.server.broadcast(
      "conversation:#{message.channel_id}",
      { type: type, channel_id: message.channel_id, message: MessageSerializer.render(message), **extra }
    )
  end

  def thread_updated(parent)
    ActionCable.server.broadcast(
      "conversation:#{parent.channel_id}",
      { type: "thread.updated", channel_id: parent.channel_id, message_id: parent.id.to_s,
        reply_count: parent.reply_count, last_reply_at: parent.last_reply_at }
    )
  end

  def presence(user, online:)
    payload = { type: "presence", user_id: user.id, online: online }
    user.workspace_memberships.pluck(:workspace_id).each do |workspace_id|
      ActionCable.server.broadcast("presence:workspace:#{workspace_id}", payload)
    end
  end

  def notify(user, payload)
    NotificationsChannel.broadcast_to(user, payload)
  end
end
