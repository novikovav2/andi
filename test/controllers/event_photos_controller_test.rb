require "test_helper"

class EventPhotosControllerTest < ActionDispatch::IntegrationTest
  setup do
    @pro_user = create_user(plan: "pro")
    @free_user = create_user(plan: "free")
  end

  test "non pro event does not show photo album link to participant" do
    event = create_event_for(@free_user, organizer_token: "free-photo-link-token")

    get event_share_path(event.access_token)

    assert_response :success
    assert_no_match "Фото мероприятия", response.body
  end

  test "pro event shows photo album link" do
    event = create_event_for(@pro_user, organizer_token: "pro-photo-link-token")

    get event_share_path(event.access_token)

    assert_response :success
    assert_select "a[href=?]",
                  event_photos_path(event, access_token: event.access_token),
                  text: "📸 Фото мероприятия · 0"
  end

  test "photo album page is unavailable for non pro event" do
    event = create_event_for(@free_user, organizer_token: "free-photo-album-token")

    get event_photos_path(event, access_token: event.access_token)

    assert_redirected_to event_share_path(event.access_token)
    assert_equal "Фото мероприятия доступны на тарифе Pro", flash[:alert]
  end

  test "can upload photo to pro event" do
    event = create_event_for(@pro_user, organizer_token: "pro-photo-upload-token")

    assert_difference -> { event.event_photos.count }, 1 do
      post event_photos_path(event, access_token: event.access_token),
           params: {
             event_photo: {
               images: [ fixture_file_upload("receipt.jpg", "image/jpeg") ]
             }
           }
    end

    assert_redirected_to event_photos_path(event, access_token: event.access_token)
    assert_equal "Фото загружены", flash[:notice]
  end

  test "uploaded photo appears in gallery" do
    event = create_event_for(@pro_user, organizer_token: "pro-photo-gallery-token")
    create_event_photo_for(event)

    get event_photos_path(event, access_token: event.access_token)

    assert_response :success
    assert_select "h1", "Фото мероприятия"
    assert_select "a.event-photo-link[href*='/rails/active_storage/blobs'][target='_blank']"
    assert_select "img.event-photo-image[alt='Фото мероприятия'][src*='/rails/active_storage/blobs']"
    assert_no_match "Участник события", response.body
  end

  test "album page has unified back link to event" do
    event = create_event_for(@pro_user, organizer_token: "pro-photo-back-link-token")

    get event_photos_path(event, access_token: event.access_token)

    assert_response :success
    assert_select "a.back-link[href=?]", event_share_path(event.access_token), text: "← К событию"
  end

  test "uploaded photo blob path is served by active storage" do
    event = create_event_for(@pro_user, organizer_token: "pro-photo-blob-token")
    event_photo = create_event_photo_for(event)

    get rails_blob_path(event_photo.image, disposition: "inline")

    assert_response :redirect

    follow_redirect!

    assert_response :success
    assert_equal "image/jpeg", response.media_type
  end

  test "gallery does not display participant placeholder when participant is missing" do
    event = create_event_for(@pro_user, organizer_token: "pro-photo-no-author-token")
    create_event_photo_for(event)

    get event_photos_path(event, access_token: event.access_token)

    assert_response :success
    assert_no_match "Участник события", response.body
    assert_no_match "Неизвестный участник", response.body
  end

  test "gallery displays participant name when participant is present" do
    event = create_event_for(@pro_user, organizer_token: "pro-photo-author-token")
    participant = event.participants.create!(name: "Катя")
    create_event_photo_for(event, participant:)

    get event_photos_path(event, access_token: event.access_token)

    assert_response :success
    assert_includes response.body, "Катя"
  end

  test "album page has multiple file input" do
    event = create_event_for(@pro_user, organizer_token: "pro-photo-input-token")

    get event_photos_path(event, access_token: event.access_token)

    assert_response :success
    assert_select "form[enctype='multipart/form-data']"
    assert_select "label[for='event_photo_images']", "Выберите фото для загрузки"
    assert_select "input[type='file'][name='event_photo[images][]'][multiple='multiple'][required='required']"
    assert_select "[data-event-photo-upload-target='selected']", "Файлы не выбраны"
  end

  test "upload without photo redirects with alert" do
    event = create_event_for(@pro_user, organizer_token: "pro-photo-empty-upload-token")

    assert_no_difference -> { event.event_photos.count } do
      post event_photos_path(event, access_token: event.access_token),
           params: { event_photo: { images: [] } }
    end

    assert_redirected_to event_photos_path(event, access_token: event.access_token)
    assert_equal "Нужно выбрать фото", flash[:alert]
  end

  test "event page photo counter updates after upload" do
    event = create_event_for(@pro_user, organizer_token: "pro-photo-counter-token")

    post event_photos_path(event, access_token: event.access_token),
         params: {
           event_photo: {
             images: [ fixture_file_upload("receipt.jpg", "image/jpeg") ]
           }
         }

    get event_share_path(event.access_token)

    assert_response :success
    assert_includes response.body, "📸 Фото мероприятия · 1"
  end

  test "organizer can delete photo" do
    event = create_event_as_signed_in_organizer(@pro_user)
    event_photo = create_event_photo_for(event)

    assert_difference -> { event.event_photos.count }, -1 do
      delete event_photo_path(event, event_photo)
    end

    assert_redirected_to event_photos_path(event)
    assert_equal "Фото удалено", flash[:notice]
  end

  test "signed in event owner sees delete button without organizer token" do
    event = create_event_for(@pro_user, organizer_token: "owner-other-device-token")
    create_event_photo_for(event)
    sign_in_as(@pro_user)

    get event_photos_path(event)

    assert_response :success
    assert_select "form.button_to[action=?]", event_photo_path(event, event.event_photos.first)
    assert_select "button.event-photo-delete-button", "Удалить"
  end

  test "signed in event owner can delete photo without organizer token" do
    event = create_event_for(@pro_user, organizer_token: "owner-delete-other-device-token")
    event_photo = create_event_photo_for(event)
    sign_in_as(@pro_user)

    assert_difference -> { event.event_photos.count }, -1 do
      delete event_photo_path(event, event_photo)
    end

    assert_redirected_to event_photos_path(event)
    assert_equal "Фото удалено", flash[:notice]
  end

  test "participant does not see delete button" do
    event = create_event_for(@pro_user, organizer_token: "pro-photo-no-delete-token")
    create_event_photo_for(event)

    get event_photos_path(event, access_token: event.access_token)

    assert_response :success
    assert_no_match "Удалить", response.body
  end

  test "participant cannot delete photo" do
    event = create_event_for(@pro_user, organizer_token: "pro-photo-delete-denied-token")
    event_photo = create_event_photo_for(event)

    assert_no_difference -> { event.event_photos.count } do
      delete event_photo_path(event, event_photo, access_token: event.access_token)
    end

    assert_redirected_to event_photos_path(event, access_token: event.access_token)
    assert_equal "Удалять фото может только организатор", flash[:alert]
  end

  private

  def create_user(plan:)
    User.create!(
      email: "photo-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      plan:
    )
  end

  def create_event_for(user, organizer_token:)
    user.events.create!(
      title: "Фото событие",
      organizer_token:
    )
  end

  def create_event_as_signed_in_organizer(user)
    sign_in_as(user)

    post events_path, params: {
      event: {
        title: "Фото событие организатора"
      }
    }

    Event.order(:created_at).last
  end

  def sign_in_as(user)
    post session_path, params: {
      email: user.email,
      password: "password123"
    }
  end

  def create_event_photo_for(event, participant: nil)
    event_photo = event.event_photos.build(participant:)
    event_photo.image.attach(
      io: Rails.root.join("test/fixtures/files/receipt.jpg").open,
      filename: "photo.jpg",
      content_type: "image/jpeg"
    )
    event_photo.save!
    event_photo
  end
end
