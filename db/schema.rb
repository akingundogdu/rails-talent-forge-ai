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

ActiveRecord::Schema[7.1].define(version: 2025_06_05_134742) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "departments", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.bigint "parent_department_id"
    t.bigint "manager_id"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_departments_on_deleted_at"
    t.index ["manager_id"], name: "index_departments_on_manager_id"
    t.index ["name"], name: "index_departments_on_name"
    t.index ["parent_department_id"], name: "index_departments_on_parent_department_id"
  end

  create_table "employees", force: :cascade do |t|
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "email", null: false
    t.bigint "position_id", null: false
    t.bigint "manager_id"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["deleted_at"], name: "index_employees_on_deleted_at"
    t.index ["email"], name: "index_employees_on_email", unique: true
    t.index ["first_name", "last_name"], name: "index_employees_on_first_name_and_last_name"
    t.index ["manager_id"], name: "index_employees_on_manager_id"
    t.index ["position_id"], name: "index_employees_on_position_id"
    t.index ["user_id"], name: "index_employees_on_user_id"
  end

  create_table "jwt_denylists", force: :cascade do |t|
    t.string "jti"
    t.datetime "exp"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["jti"], name: "index_jwt_denylists_on_jti"
  end

  create_table "permissions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "resource", null: false
    t.string "action", null: false
    t.bigint "resource_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["resource", "resource_id"], name: "index_permissions_on_resource_and_resource_id"
    t.index ["user_id", "resource", "action", "resource_id"], name: "index_permissions_on_user_resource_action", unique: true
    t.index ["user_id"], name: "index_permissions_on_user_id"
  end

  create_table "positions", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.integer "level", null: false
    t.bigint "department_id", null: false
    t.bigint "parent_position_id"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_positions_on_deleted_at"
    t.index ["department_id"], name: "index_positions_on_department_id"
    t.index ["level"], name: "index_positions_on_level"
    t.index ["parent_position_id"], name: "index_positions_on_parent_position_id"
    t.index ["title"], name: "index_positions_on_title"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.datetime "last_activity_at"
    t.datetime "encrypted_password_changed_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["last_activity_at"], name: "index_users_on_last_activity_at"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "departments", "employees", column: "manager_id"
  add_foreign_key "employees", "positions"
  add_foreign_key "employees", "users"
  add_foreign_key "permissions", "users"
  add_foreign_key "positions", "departments"
end
