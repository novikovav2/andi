class AddOrganizerTokenToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :organizer_token, :string
  end
end
