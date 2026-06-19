class AddLastChangeToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :last_change_description, :string
    add_column :events, :last_change_at, :datetime
  end
end
