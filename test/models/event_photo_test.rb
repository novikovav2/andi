require "test_helper"

class EventPhotoTest < ActiveSupport::TestCase
  setup do
    @event = Event.create!(title: "Фотоальбом", organizer_token: "event-photo-model-token")
  end

  test "is valid with image" do
    event_photo = @event.event_photos.build
    event_photo.image.attach(
      io: Rails.root.join("test/fixtures/files/receipt.jpg").open,
      filename: "photo.jpg",
      content_type: "image/jpeg"
    )

    assert_predicate event_photo, :valid?
  end

  test "requires image" do
    event_photo = @event.event_photos.build

    assert_not event_photo.valid?
    assert_not_empty event_photo.errors[:image]
  end

  test "rejects unsupported content type" do
    event_photo = @event.event_photos.build
    event_photo.image.attach(
      io: StringIO.new("not an image"),
      filename: "photo.txt",
      content_type: "text/plain"
    )

    assert_not event_photo.valid?
    assert_not_empty event_photo.errors[:image]
  end

  test "rejects image larger than 10 megabytes" do
    event_photo = @event.event_photos.build
    event_photo.image.attach(
      io: StringIO.new("0" * (10.megabytes + 1)),
      filename: "large.jpg",
      content_type: "image/jpeg"
    )

    assert_not event_photo.valid?
    assert_not_empty event_photo.errors[:image]
  end
end
