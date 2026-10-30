class CreateWorkspaceMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :workspace_memberships do |t|
      t.references :workspace, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :role, null: false, default: "member"

      t.timestamps
    end

    add_index :workspace_memberships, %i[workspace_id user_id], unique: true
    add_check_constraint :workspace_memberships, "role IN ('owner', 'admin', 'member')", name: "workspace_memberships_role_check"
  end
end
