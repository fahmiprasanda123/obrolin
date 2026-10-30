class Channel < ApplicationRecord
  NAME_FORMAT = /\A[a-z0-9_-]{1,80}\z/

  belongs_to :workspace
  belongs_to :created_by, class_name: "User"
  has_many :channel_memberships, dependent: :destroy
  has_many :members, through: :channel_memberships, source: :user

  # Slack-style names: "Design Team" becomes "design-team".
  normalizes :name, with: ->(name) { name.strip.downcase.gsub(/\s+/, "-") }

  validates :name, presence: true, uniqueness: { scope: :workspace_id },
                   format: { with: NAME_FORMAT, message: "may only contain a-z, 0-9, - and _" }
  validates :description, length: { maximum: 250 }

  # Public channels plus private channels the user belongs to.
  scope :visible_to, ->(user) {
    where(is_private: false).or(where(id: ChannelMembership.where(user: user).select(:channel_id)))
  }

  def member?(user)
    channel_memberships.exists?(user: user)
  end

  def visible_to?(user)
    !is_private? || member?(user)
  end

  def stream_name
    "conversation:#{id}"
  end
end
