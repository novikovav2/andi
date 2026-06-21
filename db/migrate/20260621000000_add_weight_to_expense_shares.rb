class AddWeightToExpenseShares < ActiveRecord::Migration[8.0]
  def change
    add_column :expense_shares, :weight, :decimal, precision: 10, scale: 3, default: 1, null: false
  end
end
