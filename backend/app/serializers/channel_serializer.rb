class ChannelSerializer
  # membership: the current user's ChannelMembership (nil if not a member)
  def self.render(channel, membership: nil, member_count: nil, unread_count: 0)
    {
      id: channel.id,
      workspace_id: channel.workspace_id,
      name: channel.name,
      description: channel.description,
      is_private: channel.is_private,
      is_default: channel.is_default,
      created_by_id: channel.created_by_id,
      is_member: membership.present?,
      last_read_at: membership&.last_read_at,
      member_count: member_count,
      unread_count: membership ? unread_count : 0,
      created_at: channel.created_at
    }
  end
end
