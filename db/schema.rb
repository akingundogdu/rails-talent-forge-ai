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

ActiveRecord::Schema[7.1].define(version: 2025_06_16_143340) do
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

  create_table "feedback_requests", force: :cascade do |t|
    t.bigint "requester_id", null: false
    t.bigint "recipient_id", null: false
    t.text "message"
    t.string "feedback_type"
    t.string "status", default: "pending"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["recipient_id"], name: "index_feedback_requests_on_recipient_id"
    t.index ["requester_id"], name: "index_feedback_requests_on_requester_id"
  end

  create_table "feedbacks", force: :cascade do |t|
    t.bigint "giver_id", null: false
    t.bigint "receiver_id", null: false
    t.bigint "performance_review_id"
    t.integer "feedback_type", default: 0, null: false
    t.text "message", null: false
    t.integer "rating"
    t.boolean "anonymous", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "sentiment_score"
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_feedbacks_on_deleted_at"
    t.index ["giver_id", "created_at"], name: "index_feedbacks_on_giver_id_and_created_at"
    t.index ["giver_id"], name: "index_feedbacks_on_giver_id"
    t.index ["performance_review_id", "feedback_type"], name: "index_feedbacks_on_performance_review_id_and_feedback_type"
    t.index ["performance_review_id"], name: "index_feedbacks_on_performance_review_id"
    t.index ["receiver_id", "feedback_type"], name: "index_feedbacks_on_receiver_id_and_feedback_type"
    t.index ["receiver_id"], name: "index_feedbacks_on_receiver_id"
  end

  create_table "goals", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.bigint "performance_review_id"
    t.string "title", null: false
    t.text "description"
    t.decimal "target_value", precision: 10, scale: 2
    t.decimal "actual_value", precision: 10, scale: 2, default: "0.0"
    t.integer "status", default: 0, null: false
    t.integer "priority", default: 1, null: false
    t.date "due_date", null: false
    t.datetime "completed_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_goals_on_deleted_at"
    t.index ["due_date", "status"], name: "index_goals_on_due_date_and_status"
    t.index ["employee_id", "status"], name: "index_goals_on_employee_id_and_status"
    t.index ["employee_id"], name: "index_goals_on_employee_id"
    t.index ["performance_review_id"], name: "index_goals_on_performance_review_id"
    t.index ["priority"], name: "index_goals_on_priority"
  end

  create_table "jwt_denylists", force: :cascade do |t|
    t.string "jti"
    t.datetime "exp"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["jti"], name: "index_jwt_denylists_on_jti"
  end

  create_table "kpis", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.bigint "position_id"
    t.string "name", null: false
    t.text "description"
    t.decimal "target_value", precision: 10, scale: 2, null: false
    t.decimal "actual_value", precision: 10, scale: 2, default: "0.0"
    t.string "measurement_unit", default: "number"
    t.date "period_start", null: false
    t.date "period_end", null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "measurement_period"
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_kpis_on_deleted_at"
    t.index ["employee_id", "period_start", "period_end"], name: "index_kpis_on_employee_id_and_period_start_and_period_end"
    t.index ["employee_id"], name: "index_kpis_on_employee_id"
    t.index ["position_id", "period_start", "period_end"], name: "index_kpis_on_position_id_and_period_start_and_period_end"
    t.index ["position_id"], name: "index_kpis_on_position_id"
    t.index ["status"], name: "index_kpis_on_status"
  end

  create_table "performance_reviews", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.bigint "reviewer_id", null: false
    t.integer "status", default: 0, null: false
    t.integer "review_type", default: 0, null: false
    t.string "title", null: false
    t.text "description"
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.datetime "completed_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["completed_at"], name: "index_performance_reviews_on_completed_at"
    t.index ["deleted_at"], name: "index_performance_reviews_on_deleted_at"
    t.index ["employee_id", "review_type"], name: "index_performance_reviews_on_employee_id_and_review_type"
    t.index ["employee_id"], name: "index_performance_reviews_on_employee_id"
    t.index ["reviewer_id"], name: "index_performance_reviews_on_reviewer_id"
    t.index ["status", "start_date"], name: "index_performance_reviews_on_status_and_start_date"
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

  create_table "ratings", force: :cascade do |t|
    t.bigint "performance_review_id", null: false
    t.string "competency_name", null: false
    t.integer "score", null: false
    t.text "comments"
    t.decimal "weight", precision: 5, scale: 2, default: "1.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_ratings_on_deleted_at"
    t.index ["performance_review_id", "competency_name"], name: "index_ratings_on_performance_review_id_and_competency_name", unique: true
    t.index ["performance_review_id"], name: "index_ratings_on_performance_review_id"
    t.index ["score"], name: "index_ratings_on_score"
    t.check_constraint "score >= 1 AND score <= 5", name: "score_range_check"
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
    t.string "jti"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["last_activity_at"], name: "index_users_on_last_activity_at"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "departments", "employees", column: "manager_id"
  add_foreign_key "employees", "positions"
  add_foreign_key "employees", "users"
  add_foreign_key "feedback_requests", "employees", column: "recipient_id"
  add_foreign_key "feedback_requests", "employees", column: "requester_id"
  add_foreign_key "feedbacks", "employees", column: "giver_id"
  add_foreign_key "feedbacks", "employees", column: "receiver_id"
  add_foreign_key "feedbacks", "performance_reviews"
  add_foreign_key "goals", "employees"
  add_foreign_key "goals", "performance_reviews"
  add_foreign_key "kpis", "employees"
  add_foreign_key "kpis", "positions"
  add_foreign_key "performance_reviews", "employees"
  add_foreign_key "performance_reviews", "employees", column: "reviewer_id"
  add_foreign_key "permissions", "users"
  add_foreign_key "positions", "departments"
  add_foreign_key "ratings", "performance_reviews"
end
