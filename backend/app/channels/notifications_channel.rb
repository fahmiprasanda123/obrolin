# Personal stream for one user (mentions and similar notifications).
class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user
  end
end
