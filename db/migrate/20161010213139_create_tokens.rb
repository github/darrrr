class CreateTokens < ActiveRecord::Migration[5.2]
  def change
    create_table :tokens do |t|
       t.string :name
       t.text :token_blob

       t.timestamps
     end
  end
end
