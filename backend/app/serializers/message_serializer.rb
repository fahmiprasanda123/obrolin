# Messages (MongoDB) reference users (PostgreSQL) by id. There is no JOIN
# across databases, so authors are loaded in one batched query and stitched
# together in Ruby (an "application-level join").
class MessageSerializer
  def self.render_many(messages)
    users = User.where(id: messages.map(&:user_id).uniq).index_by(&:id)
    messages.map { |message| render(message, user: users[message.user_id]) }
  end

  def self.render(message, user: User.find_by(id: message.user_id))
    deleted = message.deleted?
    {
      id: message.id.to_s,
      channel_id: message.channel_id,
      workspace_id: message.workspace_id,
      parent_message_id: message.parent_message_id&.to_s,
      user: user&.public_json,
      body: deleted ? nil : message.body,
      mentions: deleted ? [] : message.mentions,
      reactions: deleted ? [] : message.reactions.map { |r| { emoji: r.emoji, user_ids: r.user_ids, count: r.user_ids.size } },
      reply_count: message.reply_count,
      last_reply_at: message.last_reply_at,
      edited_at: message.edited_at,
      deleted_at: message.deleted_at,
      created_at: message.created_at
    }
  end
end
