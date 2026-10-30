module Api
  module V1
    class ProfilesController < ApplicationController
      # GET /api/v1/me
      def show
        render json: current_user
      end

      # PATCH /api/v1/me
      # Changing the password requires the current one, so a stolen token
      # alone cannot lock the real owner out.
      def update
        if profile_params[:password].present? && !current_user.authenticate(params.dig(:user, :current_password).to_s)
          return render json: { errors: { current_password: [ "Current password is incorrect" ] } },
                        status: :unprocessable_content
        end

        if current_user.update(profile_params)
          render json: current_user
        else
          render_validation_errors(current_user)
        end
      end

      private

      def profile_params
        params.require(:user).permit(:display_name, :password)
      end
    end
  end
end
