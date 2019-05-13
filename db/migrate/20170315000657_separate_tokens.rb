class SeparateTokens < ActiveRecord::Migration[5.2]
  def change
    rename_table :tokens, :recovery_tokens
    create_table :reference_tokens do |t|
      t.string :provider
      t.string :token_id
      t.timestamp :confirmed_at
      t.timestamp :recovered_at
      t.timestamps
    end
  end
end
