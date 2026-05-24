class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.string :title, null: false
      t.string :status, null: false, default: "draft"
      t.string :access_token, null: false
      t.datetime :locked_at

      t.timestamps
    end
  end
end
