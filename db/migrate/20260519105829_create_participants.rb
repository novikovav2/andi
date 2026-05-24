class CreateParticipants < ActiveRecord::Migration[8.1]
  def change
    create_table :participants do |t|
      t.references :event, null: false, foreign_key: true
      t.string :name, null: false
      t.string :color

      t.timestamps
    end
  end
end
