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

ActiveRecord::Schema[8.1].define(version: 2026_06_19_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "analytics_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type"
    t.bigint "eventable_id"
    t.string "eventable_type"
    t.json "metadata"
    t.datetime "updated_at", null: false
  end

  create_table "event_photos", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.bigint "participant_id"
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_event_photos_on_event_id"
    t.index ["participant_id"], name: "index_event_photos_on_participant_id"
  end

  create_table "events", force: :cascade do |t|
    t.string "access_token", null: false
    t.datetime "created_at", null: false
    t.datetime "last_change_at"
    t.string "last_change_description"
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
    t.bigint "receipt_scan_id"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_expenses_on_event_id"
    t.index ["payer_id"], name: "index_expenses_on_payer_id"
    t.index ["receipt_scan_id"], name: "index_expenses_on_receipt_scan_id"
  end

  create_table "participants", force: :cascade do |t|
    t.string "color"
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_participants_on_event_id"
  end

  create_table "receipt_scans", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "created_expenses_count"
    t.text "error"
    t.bigint "event_id", null: false
    t.datetime "image_purged_at"
    t.integer "processing_time_ms"
    t.jsonb "raw_result"
    t.integer "recognized_items_count"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_receipt_scans_on_event_id"
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

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "event_photos", "events"
  add_foreign_key "event_photos", "participants"
  add_foreign_key "events", "users"
  add_foreign_key "expense_shares", "expenses"
  add_foreign_key "expense_shares", "participants"
  add_foreign_key "expenses", "events"
  add_foreign_key "expenses", "participants", column: "payer_id"
  add_foreign_key "expenses", "receipt_scans"
  add_foreign_key "participants", "events"
  add_foreign_key "receipt_scans", "events"
  add_foreign_key "settlements", "events"
  add_foreign_key "settlements", "participants", column: "from_participant_id"
  add_foreign_key "settlements", "participants", column: "to_participant_id"
end
