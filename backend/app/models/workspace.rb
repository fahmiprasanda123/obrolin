class Workspace < ApplicationRecord
  DEFAULT_CHANNELS = [
    { name: "general", description: "Company-wide announcements and work-based matters" },
    { name: "random", description: "Non-work banter and water cooler conversation" }
  ].freeze

  belongs_to :owner, class_name: "User"
  has_many :workspace_memberships, dependent: :destroy
  has_many :members, through: :workspace_memberships, source: :user
  has_many :channels, dependent: :destroy
  has_many :invitations, dependent: :destroy

  validates :name, presence: true, length: { maximum: 80 }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }

  before_validation :assign_slug, on: :create

  # Creates the workspace, the owner's membership and the default channels in
  # one transaction, so a workspace never exists without an owner.
  def self.create_with_owner!(owner:, **attributes)
    transaction do
      workspace = create!(attributes.merge(owner: owner))
      workspace.workspace_memberships.create!(user: owner, role: :owner)
      DEFAULT_CHANNELS.each do |channel_attrs|
        channel = workspace.channels.create!(channel_attrs.merge(created_by: owner, is_default: true))
        channel.channel_memberships.create!(user: owner)
      end
      workspace
    end
  end

  def membership_for(user)
    workspace_memberships.find_by(user: user)
  end

  # Adds a user as a member and joins them to every default channel.
  def add_member!(user, role: :member)
    transaction do
      membership = workspace_memberships.find_or_create_by!(user: user) { |m| m.role = role }
      channels.where(is_default: true).find_each do |channel|
        channel.channel_memberships.find_or_create_by!(user: user)
      end
      membership
    end
  end

  private

  def assign_slug
    return if slug.present? || name.blank?

    base = name.parameterize.presence || "workspace"
    candidate = base
    candidate = "#{base}-#{SecureRandom.alphanumeric(4).downcase}" while Workspace.exists?(slug: candidate)
    self.slug = candidate
  end
end
