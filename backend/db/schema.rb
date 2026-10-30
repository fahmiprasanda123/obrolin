# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_10_30_035110) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "channel_memberships", force: :cascade do |t|
    t.bigint "channel_id", null: false
    t.bigint "user_id", null: false
    t.datetime "last_read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["channel_id", "user_id"], name: "index_channel_memberships_on_channel_id_and_user_id", unique: true
    t.index ["channel_id"], name: "index_channel_memberships_on_channel_id"
    t.index ["user_id"], name: "index_channel_memberships_on_user_id"
  end

  create_table "channels", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "created_by_id", null: false
    t.string "name", null: false
    t.string "description", default: "", null: false
    t.boolean "is_private", default: false, null: false
    t.boolean "is_default", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_channels_on_created_by_id"
    t.index ["workspace_id", "name"], name: "index_channels_on_workspace_id_and_name", unique: true
    t.index ["workspace_id"], name: "index_channels_on_workspace_id"
  end

  create_table "invitations", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "inviter_id", null: false
    t.bigint "accepted_by_id"
    t.string "email", null: false
    t.string "token", null: false
    t.datetime "expires_at", null: false
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["accepted_by_id"], name: "index_invitations_on_accepted_by_id"
    t.index ["inviter_id"], name: "index_invitations_on_inviter_id"
    t.index ["token"], name: "index_invitations_on_token", unique: true
    t.index ["workspace_id", "email"], name: "index_invitations_on_workspace_id_and_email"
    t.index ["workspace_id"], name: "index_invitations_on_workspace_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "username", null: false
    t.string "display_name", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "workspace_memberships", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "user_id", null: false
    t.string "role", default: "member", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_workspace_memberships_on_user_id"
    t.index ["workspace_id", "user_id"], name: "index_workspace_memberships_on_workspace_id_and_user_id", unique: true
    t.index ["workspace_id"], name: "index_workspace_memberships_on_workspace_id"
    t.check_constraint "role::text = ANY (ARRAY['owner'::character varying, 'admin'::character varying, 'member'::character varying]::text[])", name: "workspace_memberships_role_check"
  end

  create_table "workspaces", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.bigint "owner_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_workspaces_on_owner_id"
    t.index ["slug"], name: "index_workspaces_on_slug", unique: true
  end

  add_foreign_key "channel_memberships", "channels", on_delete: :cascade
  add_foreign_key "channel_memberships", "users", on_delete: :cascade
  add_foreign_key "channels", "users", column: "created_by_id"
  add_foreign_key "channels", "workspaces", on_delete: :cascade
  add_foreign_key "invitations", "users", column: "accepted_by_id"
  add_foreign_key "invitations", "users", column: "inviter_id"
  add_foreign_key "invitations", "workspaces", on_delete: :cascade
  add_foreign_key "workspace_memberships", "users", on_delete: :cascade
  add_foreign_key "workspace_memberships", "workspaces", on_delete: :cascade
  add_foreign_key "workspaces", "users", column: "owner_id"
end
