class AddRecognitionMetricsToReceiptScans < ActiveRecord::Migration[8.1]
  def change
    add_column :receipt_scans, :recognized_items_count, :integer
    add_column :receipt_scans, :created_expenses_count, :integer
    add_column :receipt_scans, :processing_time_ms, :integer
  end
end
