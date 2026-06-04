class CreateAnalyticsEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :analytics_events do |t|
      t.string :event_type
      t.string :eventable_type
      t.bigint :eventable_id
      t.json :metadata

      t.timestamps
    end
  end
end
