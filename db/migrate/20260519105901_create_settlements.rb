class CreateSettlements < ActiveRecord::Migration[8.1]
  def change
    create_table :settlements do |t|
      t.references :event, null: false, foreign_key: true
      t.references :from_participant, null: false, foreign_key: { to_table: :participants }
      t.references :to_participant, null: false, foreign_key: { to_table: :participants }
      t.integer :amount_cents
      t.boolean :paid

      t.timestamps
    end
  end
end
