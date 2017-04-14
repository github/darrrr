class AddProviderToTokens < ActiveRecord::Migration
  def change
    add_column :tokens, :provider, :string
  end
end
