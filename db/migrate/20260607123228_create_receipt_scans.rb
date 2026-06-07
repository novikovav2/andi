class CreateReceiptScans < ActiveRecord::Migration[8.1]
  def change
    create_table :receipt_scans do |t|
      t.references :event, null: false, foreign_key: true
      t.string :status
      t.jsonb :raw_result
      t.text :error

      t.timestamps
    end
  end
end
