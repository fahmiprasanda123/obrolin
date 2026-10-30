class Invitation < ApplicationRecord
  TTL = 7.days

  class NotAcceptable < StandardError; end

  belongs_to :workspace
  belongs_to :inviter, class_name: "User"
  belongs_to :accepted_by, class_name: "User", optional: true

  has_secure_token :token, length: 32

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :email_not_already_member, on: :create

  before_validation(on: :create) { self.expires_at ||= TTL.from_now }

  scope :pending, -> { where(accepted_at: nil).where("expires_at > ?", Time.current) }

  def accepted?
    accepted_at.present?
  end

  def expired?
    expires_at <= Time.current
  end

  def pending?
    !accepted? && !expired?
  end

  def url
    "#{ENV.fetch('FRONTEND_URL', 'http://localhost:5173')}/invite/#{token}"
  end

  # The invite is bound to the email it was sent to, so a forwarded link
  # cannot be used by someone else.
  def accept!(user)
    raise NotAcceptable, "This invitation has already been used" if accepted?
    raise NotAcceptable, "This invitation has expired" if expired?
    raise NotAcceptable, "This invitation was sent to a different email address" unless user.email == email

    transaction do
      workspace.add_member!(user)
      update!(accepted_at: Time.current, accepted_by: user)
    end
  end

  private

  def email_not_already_member
    return if workspace.nil? || email.blank?
    return unless workspace.members.exists?(email: email)

    errors.add(:email, "already belongs to a member of this workspace")
  end
end
