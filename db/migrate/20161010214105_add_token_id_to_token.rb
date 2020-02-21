# frozen_string_literal: true

class AddTokenIdToToken < ActiveRecord::Migration[5.2]
  def change
    add_column :tokens, :token_id, :string
  end
end
