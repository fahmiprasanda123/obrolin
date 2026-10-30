class WorkspaceMembership < ApplicationRecord
  belongs_to :workspace
  belongs_to :user

  enum :role, { member: "member", admin: "admin", owner: "owner" }, validate: true

  validates :user_id, uniqueness: { scope: :workspace_id }

  # Owners and admins can invite people and manage channels and roles.
  def manager?
    owner? || admin?
  end
end
