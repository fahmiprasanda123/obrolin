# Chat messages live in MongoDB: they are high-volume, append-mostly, and
# their shape (reactions, mentions, thread metadata) fits a document well.
# channel_id / workspace_id / user_id reference PostgreSQL rows; there are no
# cross-database foreign keys, so integrity is enforced in application code.
class Message
  include Mongoid::Document
  include Mongoid::Timestamps

  MAX_LENGTH = 4000
  MAX_DISTINCT_REACTIONS = 20
  MENTION_PATTERN = /(?<![\w@])@([a-z0-9_]{3,30})\b/i

  field :channel_id, type: Integer
  field :workspace_id, type: Integer
  field :user_id, type: Integer
  field :body, type: String
  field :mentions, type: Array, default: []      # mentioned user ids
  field :parent_message_id, type: BSON::ObjectId # set on thread replies
  field :reply_count, type: Integer, default: 0
  field :last_reply_at, type: Time
  field :edited_at, type: Time
  field :deleted_at, type: Time

  embeds_many :reactions

  # History pagination: newest first within a channel.
  index({ channel_id: 1, created_at: -1 })
  # Thread view: replies of one parent, oldest first.
  index({ parent_message_id: 1, created_at: 1 })
  # Full-text search (a collection can only have one text index).
  index({ body: "text" })

  validates :channel_id, :workspace_id, :user_id, presence: true
  validates :body, presence: true, length: { maximum: MAX_LENGTH }, unless: :deleted?

  scope :top_level, -> { where(parent_message_id: nil) }
  scope :not_deleted, -> { where(deleted_at: nil) }

  # Channel history: top-level messages, keeping deleted ones only when they
  # still have replies (shown as "message deleted" placeholders).
  def self.history_for(channel_id)
    where(channel_id: channel_id).top_level.any_of({ deleted_at: nil }, { :reply_count.gt => 0 })
  end

  # Cursor-based pagination, newest first. The cursor is the id of the oldest
  # message the client already has. Unlike OFFSET, new messages arriving at
  # the top never shift the pages the client is scrolling through.
  # Returns [messages, next_cursor].
  def self.page(scope, before: nil, limit: 30)
    limit = limit.to_i.clamp(1, 100)
    if before.present? && BSON::ObjectId.legal?(before) && (cursor = where(_id: before).first)
      scope = scope.and(
        "$or" => [
          { created_at: { "$lt" => cursor.created_at } },
          { created_at: cursor.created_at, _id: { "$lt" => cursor._id } }
        ]
      )
    end

    records = scope.order(created_at: :desc, _id: :desc).limit(limit + 1).to_a
    has_more = records.size > limit
    records = records.first(limit)
    [ records, has_more ? records.last.id.to_s : nil ]
  end

  def self.extract_usernames(text)
    text.to_s.scan(MENTION_PATTERN).flatten.map(&:downcase).uniq
  end

  def deleted?
    deleted_at.present?
  end

  def reply?
    parent_message_id.present?
  end

  def parent
    reply? ? Message.where(_id: parent_message_id).first : nil
  end

  # Resolves @usernames in the body to ids of members of this workspace.
  def assign_mentions
    usernames = self.class.extract_usernames(body)
    self.mentions = if usernames.empty?
      []
    else
      User.joins(:workspace_memberships)
          .where(workspace_memberships: { workspace_id: workspace_id }, username: usernames)
          .pluck(:id)
    end
  end

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  # Adds the user's reaction, or removes it if they already reacted.
  def toggle_reaction!(emoji, user_id)
    reaction = reactions.detect { |r| r.emoji == emoji }

    if reaction.nil?
      if reactions.size >= MAX_DISTINCT_REACTIONS
        errors.add(:reactions, "limit reached")
        raise Mongoid::Errors::Validations, self
      end
      reactions.create!(emoji: emoji, user_ids: [ user_id ])
    elsif reaction.user_ids.include?(user_id)
      reaction.user_ids.size == 1 ? reaction.destroy : reaction.pull(user_ids: user_id)
    else
      reaction.add_to_set(user_ids: user_id)
    end
  end
end
