class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :name
      t.string :password_digest, null: false
      t.string :plan, null: false, default: "free"

      t.index :email, unique: true

      t.timestamps
    end
  end
end
