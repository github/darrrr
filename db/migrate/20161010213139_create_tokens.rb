class CreateTokens < ActiveRecord::Migration
  def change
    create_table :tokens do |t|
       t.string :name
       t.text :token_blob

       t.timestamps
     end
  end
end
