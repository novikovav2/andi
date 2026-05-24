class CreateExpenseShares < ActiveRecord::Migration[8.1]
  def change
    create_table :expense_shares do |t|
      t.references :expense, null: false, foreign_key: true
      t.references :participant, null: false, foreign_key: true

      t.timestamps
    end
  end
end
