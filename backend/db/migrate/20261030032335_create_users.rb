class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :username, null: false
      t.string :display_name, null: false
      t.string :password_digest, null: false

      t.timestamps
    end

    # Emails and usernames are normalized to lowercase in the model, so plain
    # unique indexes are enough to enforce case-insensitive uniqueness.
    add_index :users, :email, unique: true
    add_index :users, :username, unique: true
  end
end
