module EventPhotosHelper
  def event_photo_image_available?(event_photo)
    return false unless event_photo&.image&.attached?
    return true unless Rails.env.development? || Rails.env.test?

    event_photo.image.blob.service.exist?(event_photo.image.blob.key)
  rescue ActiveStorage::FileNotFoundError, StandardError
    false
  end

  def event_photo_image_path(event_photo)
    return unless event_photo_image_available?(event_photo)

    rails_blob_path(event_photo.image, disposition: "inline")
  end
end
