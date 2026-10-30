module Api
  module V1
    class MessagesController < ApplicationController
      include WorkspaceAccess

      before_action -> { load_channel!(params[:channel_id]) }, only: %i[index create search]
      before_action :require_channel_member!, only: :create
      before_action :load_message, only: %i[update destroy replies]

      # Redis-backed (via Rails.cache) protection against message floods.
      rate_limit to: 20, within: 10.seconds, by: -> { current_user.id }, only: :create,
                 with: -> { render json: { error: "You are sending messages too fast" }, status: :too_many_requests }

      # GET /channels/:channel_id/messages?before=<message_id>&limit=30
      def index
        messages, next_cursor = Message.page(Message.history_for(channel.id), before: params[:before],
                                                                              limit: params[:limit] || 30)
        render json: { messages: MessageSerializer.render_many(messages), next_cursor: next_cursor }
      end

      # POST /channels/:channel_id/messages  { message: { body, parent_message_id } }
      def create
        parent = find_parent
        return if performed?

        message = Message.new(body: message_params[:body], channel_id: channel.id, workspace_id: workspace.id,
                              user_id: current_user.id, parent_message_id: parent&.id)
        message.assign_mentions
        return render_validation_errors(message) unless message.save

        if parent
          parent.inc(reply_count: 1)
          parent.set(last_reply_at: message.created_at)
          Broadcaster.thread_updated(parent)
        end
        Broadcaster.message("message.created", message)
        NotifyMentionsJob.perform_later(message.id.to_s, message.mentions) if message.mentions.any?

        render json: MessageSerializer.render(message, user: current_user), status: :created
      end

      # PATCH /messages/:id  { message: { body } }  (author only)
      def update
        return render_forbidden("You can only edit your own messages") unless @message.user_id == current_user.id
        return render_forbidden("Deleted messages cannot be edited") if @message.deleted?

        previous_mentions = @message.mentions
        @message.body = message_params[:body]
        @message.assign_mentions
        @message.edited_at = Time.current
        return render_validation_errors(@message) unless @message.save

        Broadcaster.message("message.updated", @message)
        new_mentions = @message.mentions - previous_mentions
        NotifyMentionsJob.perform_later(@message.id.to_s, new_mentions) if new_mentions.any?
        render json: MessageSerializer.render(@message, user: current_user)
      end

      # DELETE /messages/:id  (author or workspace admin) : soft delete
      def destroy
        unless @message.user_id == current_user.id || membership.manager?
          return render_forbidden("You can only delete your own messages")
        end
        return head(:no_content) if @message.deleted?

        @message.soft_delete!
        if (parent = @message.parent)
          parent.inc(reply_count: -1)
          Broadcaster.thread_updated(parent)
        end
        Broadcaster.message("message.deleted", @message)
        ActivityLog.record("message.deleted", actor: current_user, target: @message,
                                              workspace_id: @message.workspace_id, channel_id: @message.channel_id)
        head :no_content
      end

      # GET /messages/:id/replies : the parent and its replies, oldest first.
      def replies
        thread = Message.where(parent_message_id: @message.id).not_deleted.order(created_at: :asc).limit(500).to_a
        render json: { parent: MessageSerializer.render(@message), replies: MessageSerializer.render_many(thread) }
      end

      # GET /channels/:channel_id/messages/search?q=deploy
      def search
        query = params[:q].to_s.strip
        return render json: { messages: [] } if query.length < 2

        results = Message.where(channel_id: channel.id, deleted_at: nil, "$text" => { "$search" => query })
                         .order(created_at: :desc).limit(50).to_a
        render json: { messages: MessageSerializer.render_many(results) }
      end

      private

      def message_params
        params.require(:message).permit(:body, :parent_message_id)
      end

      # Messages are looked up by id, then access is checked through the
      # channel they belong to (404 for anyone who cannot see that channel).
      def load_message
        @message = Message.find(params[:id])
        load_channel!(@message.channel_id)
      end

      def find_parent
        parent_id = message_params[:parent_message_id]
        return nil if parent_id.blank?

        parent = BSON::ObjectId.legal?(parent_id) && Message.where(_id: parent_id, channel_id: channel.id).first
        if !parent || parent.reply? || parent.deleted?
          render json: { error: "Invalid parent message" }, status: :unprocessable_content
          return nil
        end
        parent
      end
    end
  end
end
