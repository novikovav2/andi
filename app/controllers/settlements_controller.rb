class SettlementsController < ApplicationController
  before_action :set_noindex
  def index
    @event = Event.find_by(access_token: params[:access_token])
    return render_not_found if @event.blank?

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

    Analytics.track(
      "settlement_paid",
      eventable: @settlement
    )

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

  private
  def set_noindex
    response.set_header(
      "X-Robots-Tag",
      "noindex, nofollow"
    )
  end
end
