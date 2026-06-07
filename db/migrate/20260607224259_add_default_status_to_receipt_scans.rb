class AddDefaultStatusToReceiptScans < ActiveRecord::Migration[8.1]
  def change
    change_column_default :receipt_scans, :status, from: nil, to: "pending"
    change_column_null :receipt_scans, :status, false, "pending"
  end
end
