class CreateEventPhotos < ActiveRecord::Migration[8.1]
  def change
    create_table :event_photos do |t|
      t.references :event, null: false, foreign_key: true
      t.references :participant, null: true, foreign_key: true

      t.timestamps
    end
  end
end
