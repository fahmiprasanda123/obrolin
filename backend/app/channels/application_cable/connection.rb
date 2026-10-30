module ApplicationCable
  # Browsers cannot set an Authorization header on a WebSocket handshake, so
  # the same JWT used for REST is passed as a query param: /cable?token=<jwt>.
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :connection_id

    def connect
      self.current_user = find_verified_user
      self.connection_id = SecureRandom.uuid
      came_online = Presence.connect(current_user.id, connection_id)
      Broadcaster.presence(current_user, online: true) if came_online
    end

    def disconnect
      return unless current_user

      went_offline = Presence.disconnect(current_user.id, connection_id)
      Broadcaster.presence(current_user, online: false) if went_offline
    end

    private

    def find_verified_user
      payload = JsonWebToken.decode(request.params[:token].to_s)
      User.find_by(id: payload["sub"]) || reject_unauthorized_connection
    rescue JsonWebToken::InvalidToken
      reject_unauthorized_connection
    end
  end
end
