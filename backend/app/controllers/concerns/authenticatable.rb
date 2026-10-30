module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  private

  attr_reader :current_user, :current_token_payload

  def authenticate_user!
    token = request.authorization.to_s[/\ABearer (.+)\z/, 1]
    return render_unauthorized("Missing token") if token.blank?

    @current_token_payload = JsonWebToken.decode(token)
    @current_user = User.find_by(id: @current_token_payload["sub"])
    render_unauthorized("User not found") unless @current_user
  rescue JsonWebToken::InvalidToken => e
    render_unauthorized(e.message)
  end

  def render_unauthorized(message)
    render json: { error: message }, status: :unauthorized
  end
end
