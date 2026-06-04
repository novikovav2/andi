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

ActiveRecord::Schema[8.1].define(version: 2026_06_04_194641) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "analytics_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type"
    t.bigint "eventable_id"
    t.string "eventable_type"
    t.json "metadata"
    t.datetime "updated_at", null: false
  end

  create_table "events", force: :cascade do |t|
    t.string "access_token", null: false
    t.datetime "created_at", null: false
    t.datetime "locked_at"
    t.string "organizer_token"
    t.string "status", default: "draft", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["user_id"], name: "index_events_on_user_id"
  end

  create_table "expense_shares", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "expense_id", null: false
    t.bigint "participant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["expense_id"], name: "index_expense_shares_on_expense_id"
    t.index ["participant_id"], name: "index_expense_shares_on_participant_id"
  end

  create_table "expenses", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.bigint "payer_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_expenses_on_event_id"
    t.index ["payer_id"], name: "index_expenses_on_payer_id"
  end

  create_table "participants", force: :cascade do |t|
    t.string "color"
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_participants_on_event_id"
  end

  create_table "settlements", force: :cascade do |t|
    t.integer "amount_cents"
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.bigint "from_participant_id", null: false
    t.boolean "paid"
    t.bigint "to_participant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_settlements_on_event_id"
    t.index ["from_participant_id"], name: "index_settlements_on_from_participant_id"
    t.index ["to_participant_id"], name: "index_settlements_on_to_participant_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name"
    t.string "password_digest", null: false
    t.string "plan", default: "free", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "events", "users"
  add_foreign_key "expense_shares", "expenses"
  add_foreign_key "expense_shares", "participants"
  add_foreign_key "expenses", "events"
  add_foreign_key "expenses", "participants", column: "payer_id"
  add_foreign_key "participants", "events"
  add_foreign_key "settlements", "events"
  add_foreign_key "settlements", "participants", column: "from_participant_id"
  add_foreign_key "settlements", "participants", column: "to_participant_id"
end
