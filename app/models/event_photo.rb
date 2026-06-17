class EventPhoto < ApplicationRecord
  MAX_IMAGE_SIZE = 10.megabytes
  SUPPORTED_CONTENT_TYPES = %w[
    image/jpeg
    image/png
    image/webp
    image/heic
    image/heif
  ].freeze

  belongs_to :event
  belongs_to :participant, optional: true

  has_one_attached :image

  validates :event, presence: true
  validates :image, presence: true
  validate :image_content_type
  validate :image_size

  private

  def image_content_type
    return unless image.attached?
    return if SUPPORTED_CONTENT_TYPES.include?(image.blob.content_type.to_s)

    errors.add(:image, "должно быть изображением JPEG, PNG, WebP, HEIC или HEIF")
  end

  def image_size
    return unless image.attached?
    return if image.blob.byte_size <= MAX_IMAGE_SIZE

    errors.add(:image, "должно быть меньше 10 МБ")
  end
end
