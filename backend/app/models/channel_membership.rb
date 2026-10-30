class ChannelMembership < ApplicationRecord
  belongs_to :channel
  belongs_to :user

  validates :user_id, uniqueness: { scope: :channel_id }
  validate :user_belongs_to_workspace

  before_create { self.last_read_at ||= Time.current }

  private

  def user_belongs_to_workspace
    return if channel.nil? || user.nil?
    return if WorkspaceMembership.exists?(workspace_id: channel.workspace_id, user_id: user_id)

    errors.add(:user, "is not a member of this workspace")
  end
end
