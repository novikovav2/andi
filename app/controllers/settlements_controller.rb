class SettlementsController < ApplicationController
  def index
    @event = Event.find_by!(access_token: params[:access_token])
    @settlements = @event.settlements.includes(:from_participant, :to_participant).order(:created_at)
  end

  def update
    @settlement = Settlement.find(params[:id])

    @settlement.update!(paid: true)

    event = @settlement.event

    if event.settlements.exists? &&
       event.settlements.where(paid: false).none?

      event.update!(status: "settled")
    end

    respond_to do |format|
      format.html do
        redirect_to event_share_path(event.access_token),
                    notice: "Перевод отмечен как оплаченный"
      end

      format.turbo_stream do
        flash.now[:notice] = "Перевод отмечен как оплаченный"

        render turbo_stream: [
          turbo_stream.replace("flash", partial: "shared/flash"),
          turbo_stream.replace(
            @settlement,
            partial: "balance_explanations/settlement",
            locals: {
              settlement: @settlement,
              active: true
            }
          )
        ]
      end
    end
  end

  def unpay
    @settlement = Settlement.find(params[:id])
    @settlement.update!(paid: false)

    event = @settlement.event
    event.update!(status: "confirmed") if event.settled?

    respond_to do |format|
      format.html do
        redirect_back fallback_location: event_share_path(event.access_token),
                      notice: "Отметка оплаты отменена"
      end

      format.turbo_stream do
        flash.now[:notice] = "Отметка оплаты отменена"

        render turbo_stream: [
          turbo_stream.replace("flash", partial: "shared/flash"),
          turbo_stream.replace(
            @settlement,
            partial: "balance_explanations/settlement",
            locals: {
              settlement: @settlement,
              active: true
            }
          )
        ]
      end
    end
  end
end
