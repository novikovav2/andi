class EventConfirmationsController < ApplicationController
  def update
    @event = Event.find(params[:event_id])

    @event.settlements.destroy_all

    BalanceCalculator.new(@event).call.each do |settlement|
      @event.settlements.create!(
        from_participant: settlement[:from],
        to_participant: settlement[:to],
        amount_cents: settlement[:amount_cents],
        paid: false
      )
    end

    @event.update!(status: "confirmed", locked_at: Time.current)

    respond_to do |format|
      format.html do
        redirect_to event_share_path(@event.access_token),
                    notice: "Расчёт подтверждён"
      end

      format.turbo_stream do
        flash.now[:notice] = "Расчёт подтверждён"

        render turbo_stream: [
          turbo_stream.replace("flash", partial: "shared/flash"),
          *event_refresh_streams(@event)
        ]
      end
    end
  end
end