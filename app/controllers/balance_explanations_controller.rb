class BalanceExplanationsController < ApplicationController
  def show
    @event = Event.find_by!(access_token: params[:access_token])
    @from = @event.participants.find(params[:from_id])
    @to = @event.participants.find(params[:to_id])

    @settlement = @event.settlements.find_by(
      from_participant: @from,
      to_participant: @to
    )

    @outgoing_settlements = @event.settlements
                                  .where(from_participant: @from)
                                  .includes(:to_participant)
                                  .order(:created_at)

    @explanation = BalanceExplainer.new(@event, @from, @to).call

    @rows = @explanation[:consumed_rows]
    @total_consumed_cents = @explanation[:total_consumed_cents]
    @total_paid_cents = @explanation[:total_paid_cents]
    @net_owed_cents = @explanation[:net_owed_cents]
  end
end