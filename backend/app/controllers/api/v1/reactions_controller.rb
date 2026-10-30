module Api
  module V1
    class ReactionsController < ApplicationController
      include WorkspaceAccess

      # POST /messages/:message_id/reactions  { emoji: "👍" } : toggles
      def create
        message = Message.find(params[:message_id])
        load_channel!(message.channel_id)
        return render_forbidden("Join this channel first") unless channel.member?(current_user)
        return render_forbidden("Deleted messages cannot be reacted to") if message.deleted?

        message.toggle_reaction!(params.require(:emoji).to_s, current_user.id)
        message.reload
        Broadcaster.message("message.updated", message)
        render json: MessageSerializer.render(message)
      rescue Mongoid::Errors::Validations
        render json: { error: "Invalid or too many reactions" }, status: :unprocessable_content
      end
    end
  end
end
