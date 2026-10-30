# Unread count = messages in a channel created after the user's last_read_at
# (stored in PostgreSQL), excluding their own and deleted messages.
#
# Instead of one count query per channel, a single MongoDB aggregation
# matches every channel's condition and groups the results by channel_id.
module UnreadCounter
  module_function

  # memberships: ChannelMembership records of `user`.
  # Returns { channel_id => count } (channels with zero unread are omitted).
  def counts(user, memberships)
    return {} if memberships.empty?

    per_channel = memberships.map do |m|
      { "channel_id" => m.channel_id, "created_at" => { "$gt" => m.last_read_at || Time.at(0) } }
    end

    pipeline = [
      { "$match" => { "$or" => per_channel, "user_id" => { "$ne" => user.id },
                      "deleted_at" => nil, "parent_message_id" => nil } },
      { "$group" => { "_id" => "$channel_id", "count" => { "$sum" => 1 } } }
    ]
    Message.collection.aggregate(pipeline).to_h { |row| [ row["_id"], row["count"] ] }
  end
end
