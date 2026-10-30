class CreateChannelMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :channel_memberships do |t|
      t.references :channel, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      # Messages created after this timestamp count as unread.
      t.datetime :last_read_at

      t.timestamps
    end

    add_index :channel_memberships, %i[channel_id user_id], unique: true
  end
end
