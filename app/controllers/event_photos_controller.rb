class EventPhotosController < ApplicationController
  before_action :set_event
  before_action :require_event_access!
  before_action :require_event_photos_feature
  before_action :set_event_photo, only: [ :destroy ]
  before_action :require_photo_manager!, only: [ :destroy ]
  before_action :set_noindex

  def index
    @event_photos = @event.event_photos
                          .includes(:participant, image_attachment: :blob)
                          .order(created_at: :desc)
  end

  def create
    uploaded_images = Array(params.dig(:event_photo, :images)).reject(&:blank?)

    if uploaded_images.empty?
      redirect_to album_path, alert: "Нужно выбрать фото"
      return
    end

    created_count = create_event_photos(uploaded_images)

    if created_count.positive?
      redirect_to album_path, notice: "Фото загружены"
    else
      redirect_to album_path, alert: "Не удалось загрузить фото"
    end
  end

  def destroy
    @event_photo.destroy!

    redirect_to album_path, notice: "Фото удалено"
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def set_event_photo
    @event_photo = @event.event_photos.find(params[:id])
  end

  def require_event_access!
    return if valid_event_access_token?
    return if organizer?(@event)
    return if signed_in? && @event.user == current_user

    render_not_found
  end

  def require_event_photos_feature
    return if @event.photos_enabled?

    redirect_to event_share_path(@event.access_token),
                alert: "Фото мероприятия доступны на тарифе Pro"
  end

  def require_photo_manager!
    return if event_owner_or_guest_organizer?(@event)

    redirect_to album_path, alert: "Удалять фото может только организатор"
  end

  def create_event_photos(uploaded_images)
    created_count = 0

    uploaded_images.each do |image|
      event_photo = @event.event_photos.build(participant: current_participant)
      event_photo.image.attach(image)
      created_count += 1 if event_photo.save
    end

    created_count
  end

  def current_participant
    nil
  end

  def album_path
    event_photos_path(@event, { access_token: params[:access_token] }.compact_blank)
  end

  def valid_event_access_token?
    params[:access_token].present? &&
      @event.access_token.present? &&
      ActiveSupport::SecurityUtils.secure_compare(
        params[:access_token],
        @event.access_token
      )
  end

  def set_noindex
    response.set_header("X-Robots-Tag", "noindex, nofollow")
  end
end
