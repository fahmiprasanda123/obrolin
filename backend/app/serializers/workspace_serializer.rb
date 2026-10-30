class WorkspaceSerializer
  def self.render(workspace, membership: nil)
    {
      id: workspace.id,
      name: workspace.name,
      slug: workspace.slug,
      owner_id: workspace.owner_id,
      role: membership&.role,
      created_at: workspace.created_at
    }
  end
end
