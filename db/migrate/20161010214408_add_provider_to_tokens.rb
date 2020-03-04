# frozen_string_literal: true

class AddProviderToTokens < ActiveRecord::Migration[5.2]
  def change
    add_column :tokens, :provider, :string
  end
end
