class CreateChannels < ActiveRecord::Migration[8.0]
  def change
    create_table :channels do |t|
      t.references :workspace, null: false, foreign_key: { on_delete: :cascade }
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.string :description, null: false, default: ""
      t.boolean :is_private, null: false, default: false
      # Default channels (#general, #random) are joined automatically by new members.
      t.boolean :is_default, null: false, default: false

      t.timestamps
    end

    add_index :channels, %i[workspace_id name], unique: true
  end
end
