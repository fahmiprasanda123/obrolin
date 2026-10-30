class MentionMailer < ApplicationMailer
  def mentioned
    @user = params[:user]
    @author = params[:author]
    @channel = params[:channel]
    @message_body = params[:message_body]
    @url = "#{ENV.fetch('FRONTEND_URL', 'http://localhost:5173')}/workspaces/#{@channel.workspace_id}/channels/#{@channel.id}"
    mail(to: @user.email, subject: "#{@author.display_name} mentioned you in ##{@channel.name}")
  end
end
