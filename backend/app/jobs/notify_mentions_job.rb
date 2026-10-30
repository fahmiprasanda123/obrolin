# Runs in Sidekiq so posting a message stays fast no matter how many people
# are mentioned. Online users get a real-time notification; offline users
# also get an email.
class NotifyMentionsJob < ApplicationJob
  queue_as :default

  def perform(message_id, user_ids)
    message = Message.where(_id: message_id).first
    return if message.nil? || message.deleted?

    channel = Channel.find_by(id: message.channel_id)
    author = User.find_by(id: message.user_id)
    return unless channel && author

    User.where(id: user_ids).where.not(id: author.id).find_each do |user|
      # Never leak a private channel to someone who is not in it.
      next unless channel.visible_to?(user)

      Broadcaster.notify(user, {
        type: "mention",
        workspace_id: channel.workspace_id,
        channel: { id: channel.id, name: channel.name },
        message: MessageSerializer.render(message, user: author)
      })
      ActivityLog.record("message.mentioned", actor: author, target: message,
                                              workspace_id: channel.workspace_id, mentioned_user_id: user.id)
      unless Presence.online_user?(user.id)
        MentionMailer.with(user: user, author: author, channel: channel, message_body: message.body).mentioned.deliver_now
      end
    end
  end
end
