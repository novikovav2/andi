class CreateExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :expenses do |t|
      t.references :event, null: false, foreign_key: true
      t.references :payer, null: false, foreign_key: { to_table: :participants }
      t.string :title, null: false
      t.integer :amount_cents, null: false

      t.timestamps
    end
  end
end
