class AddImagePurgedAtToReceiptScans < ActiveRecord::Migration[8.1]
  def change
    add_column :receipt_scans, :image_purged_at, :datetime
  end
end
