# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2017_03_15_000657) do

  create_table "recovery_tokens", force: :cascade do |t|
    t.string "name"
    t.text "token_blob"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "token_id"
    t.string "provider"
  end

  create_table "reference_tokens", force: :cascade do |t|
    t.string "provider"
    t.string "token_id"
    t.datetime "confirmed_at"
    t.datetime "recovered_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end
