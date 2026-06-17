class AddReceiptScanToExpenses < ActiveRecord::Migration[8.1]
  def change
    add_reference :expenses, :receipt_scan, foreign_key: true, null: true
  end
end
