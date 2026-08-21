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

ActiveRecord::Schema[7.1].define(version: 2026_08_21_120000) do
  create_table "automator_actions", force: :cascade do |t|
    t.integer "flow_id", null: false
    t.string "kind", default: "builtin", null: false
    t.string "builtin_name"
    t.string "handler_key"
    t.text "options"
    t.integer "delay_seconds", default: 0, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["flow_id"], name: "index_automator_actions_on_flow_id"
  end

  create_table "automator_cancel_conditions", force: :cascade do |t|
    t.integer "flow_id", null: false
    t.string "kind", default: "structured", null: false
    t.text "config"
    t.string "predicate_key"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["flow_id"], name: "index_automator_cancel_conditions_on_flow_id"
  end

  create_table "automator_conditions", force: :cascade do |t|
    t.integer "flow_id", null: false
    t.string "kind", default: "structured", null: false
    t.text "config"
    t.string "predicate_key"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["flow_id"], name: "index_automator_conditions_on_flow_id"
  end

  create_table "automator_executions", force: :cascade do |t|
    t.integer "flow_id"
    t.integer "job_id"
    t.string "event"
    t.string "outcome", null: false
    t.text "detail"
    t.string "tenant"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_automator_executions_on_created_at"
    t.index ["flow_id"], name: "index_automator_executions_on_flow_id"
    t.index ["job_id"], name: "index_automator_executions_on_job_id"
    t.index ["outcome"], name: "index_automator_executions_on_outcome"
  end

  create_table "automator_flows", force: :cascade do |t|
    t.string "name", null: false
    t.string "key", null: false
    t.boolean "enabled", default: true, null: false
    t.boolean "dry_run", default: false, null: false
    t.text "description"
    t.string "tenant"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "once_per"
    t.string "once_per_group"
    t.string "subject_association"
    t.index ["enabled"], name: "index_automator_flows_on_enabled"
    t.index ["key"], name: "index_automator_flows_on_key", unique: true
    t.index ["once_per_group"], name: "index_automator_flows_on_once_per_group"
    t.index ["tenant"], name: "index_automator_flows_on_tenant"
  end

  create_table "automator_jobs", force: :cascade do |t|
    t.integer "flow_id", null: false
    t.integer "action_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "run_at", precision: nil, null: false
    t.text "payload"
    t.integer "attempts", default: 0, null: false
    t.text "error"
    t.string "idempotency_key"
    t.string "tenant"
    t.datetime "started_at", precision: nil
    t.datetime "finished_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "dedupe_key"
    t.index ["action_id"], name: "index_automator_jobs_on_action_id"
    t.index ["dedupe_key"], name: "index_automator_jobs_on_dedupe_key"
    t.index ["flow_id"], name: "index_automator_jobs_on_flow_id"
    t.index ["idempotency_key"], name: "index_automator_jobs_on_idempotency_key", unique: true
    t.index ["run_at"], name: "index_automator_jobs_on_run_at"
    t.index ["status"], name: "index_automator_jobs_on_status"
    t.index ["tenant"], name: "index_automator_jobs_on_tenant"
  end

  create_table "automator_triggers", force: :cascade do |t|
    t.integer "flow_id", null: false
    t.string "event", null: false
    t.string "record_type"
    t.text "change_filter"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event"], name: "index_automator_triggers_on_event"
    t.index ["flow_id"], name: "index_automator_triggers_on_flow_id"
  end

  add_foreign_key "automator_actions", "automator_flows", column: "flow_id"
  add_foreign_key "automator_cancel_conditions", "automator_flows", column: "flow_id"
  add_foreign_key "automator_conditions", "automator_flows", column: "flow_id"
  add_foreign_key "automator_executions", "automator_flows", column: "flow_id"
  add_foreign_key "automator_executions", "automator_jobs", column: "job_id"
  add_foreign_key "automator_jobs", "automator_actions", column: "action_id"
  add_foreign_key "automator_jobs", "automator_flows", column: "flow_id"
  add_foreign_key "automator_triggers", "automator_flows", column: "flow_id"
end
