module WorkspaceHelpers
  def add_member(workspace, user = create(:user), role: :member)
    workspace.add_member!(user, role: role)
    user
  end
end

RSpec.configure do |config|
  config.include WorkspaceHelpers
end
