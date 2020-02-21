# frozen_string_literal: true

# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
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
