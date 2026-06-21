module EventRefreshable
  extend ActiveSupport::Concern

  private

  def event_refresh_streams(event)
    participants = event.participants.order(:created_at)
    participant_form = Participant.new
    expenses = event.expenses
                    .includes(:payer, :participants, receipt_scan: { image_attachment: :blob })
                    .order(created_at: :desc)

    streams = [
      turbo_stream.replace(
        "event_header",
        partial: "events/header",
        locals: { event:, participants: }
      ),

      turbo_stream.replace(
        "event_status",
        partial: "events/status",
        locals: { event: }
      ),

      turbo_stream.replace(
        "event_progress",
        partial: "events/progress_card",
        locals: { event: }
      ),

      turbo_stream.replace(
        "participants",
        partial: "events/participants",
        locals: {
          event:,
          participants:,
          participant_form:
        }
      ),

      turbo_stream.replace(
        "event_photos_entry",
        partial: "events/event_photos_link",
        locals: { event: }
      ),

      turbo_stream.replace(
        "expense_locked_state",
        partial: "events/expense_locked_state",
        locals: { participants: }
      ),

      turbo_stream.replace(
        "receipt_upload_action",
        partial: "events/receipt_upload_action",
        locals: {
          event:,
          participants:
        }
      ),

      turbo_stream.replace(
        "expenses",
        partial: "events/expenses",
        locals: {
          event:,
          expenses:,
          participants:
        }
      ),

      turbo_stream.replace(
        "expense_fab",
        partial: "events/expense_fab",
        locals: { event:, participants: }
      ),

      turbo_stream.replace(
        "confirm_bar",
        partial: "events/confirm_bar",
        locals: { event: }
      ),

      turbo_stream.replace(
        "settlements",
        partial: "events/settlements",
        locals: {
          event: event,
          settlements: event.settlements.includes(:from_participant, :to_participant)
        }
      )
    ]

    expenses.each do |expense|
      streams << turbo_stream.replace(
        expense,
        partial: "expenses/expense",
        locals: { expense: }
      )
    end

    streams
  end
end
