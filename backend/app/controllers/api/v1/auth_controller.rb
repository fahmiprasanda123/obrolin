module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate_user!, only: %i[register login]

      # Slows down password guessing and signup spam. Counters live in
      # Rails.cache (Redis), so the limit holds across all api pods.
      # Keyed by client IP; behind the ingress/Vite proxy Rails reads it from
      # X-Forwarded-For.
      rate_limit to: 10, within: 3.minutes, only: %i[login register],
                 with: -> { render json: { error: "Too many attempts. Try again in a few minutes." }, status: :too_many_requests }

      # POST /api/v1/auth/register
      def register
        user = User.new(register_params)
        if user.save
          render json: token_response(user), status: :created
        else
          render_validation_errors(user)
        end
      end

      # POST /api/v1/auth/login
      # Accepts either an email or a username in the "login" field.
      def login
        identifier = params.require(:login).to_s.strip.downcase
        user = User.find_by(email: identifier) || User.find_by(username: identifier)

        if user&.authenticate(params.require(:password))
          render json: token_response(user)
        else
          render json: { error: "Invalid login or password" }, status: :unauthorized
        end
      end

      # DELETE /api/v1/auth/logout
      def logout
        JsonWebToken.revoke(current_token_payload)
        head :no_content
      end

      private

      def register_params
        params.require(:user).permit(:email, :username, :display_name, :password)
      end

      def token_response(user)
        { token: JsonWebToken.encode(user.id), user: user }
      end
    end
  end
end
