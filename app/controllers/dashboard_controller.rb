class DashboardController < ApplicationController
  before_action :require_user!

  def index
    @active_events = dashboard_events(Event.active)
    @archived_events = dashboard_events(Event.settled)
  end

  private
  def dashboard_events(scope)
    current_user.events
                .merge(scope)
                .select(
                  "events.*",
                  "(SELECT COUNT(*) FROM participants WHERE participants.event_id = events.id) AS participants_count",
                  "(SELECT COALESCE(SUM(expenses.amount_cents), 0) FROM expenses WHERE expenses.event_id = events.id) AS total_expenses_cents"
                )
                .order(created_at: :desc)
  end
end
