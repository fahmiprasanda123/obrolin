class User < ApplicationRecord
  USERNAME_FORMAT = /\A[a-z0-9_]{3,30}\z/

  has_secure_password

  has_many :workspace_memberships, dependent: :destroy
  has_many :workspaces, through: :workspace_memberships
  has_many :channel_memberships, dependent: :destroy
  has_many :channels, through: :channel_memberships

  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :username, with: ->(username) { username.strip.downcase }

  validates :email, presence: true, uniqueness: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  # Usernames are used for @mentions, so keep them simple and URL-safe.
  validates :username, presence: true, uniqueness: true,
                       format: { with: USERNAME_FORMAT, message: "may only contain a-z, 0-9 and _ (3-30 chars)" }
  validates :display_name, presence: true, length: { maximum: 50 }
  validates :password, length: { minimum: 8 }, allow_nil: true

  def as_json(_options = {})
    {
      id: id,
      email: email,
      username: username,
      display_name: display_name,
      created_at: created_at
    }
  end

  # Public view of a user shown to other members (no email).
  def public_json
    { id: id, username: username, display_name: display_name }
  end
end
