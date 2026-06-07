require "test_helper"

class ReceiptScanTest < ActiveSupport::TestCase
  setup do
    @event = Event.create!(
      title: "Receipt trip",
      organizer_token: "receipt-token"
    )
  end

  test "defaults to pending status" do
    receipt_scan = @event.receipt_scans.build

    assert_predicate receipt_scan, :pending?
  end

  test "requires image" do
    receipt_scan = @event.receipt_scans.build

    assert_not receipt_scan.valid?
    assert_not_empty receipt_scan.errors[:image]
  end

  test "is valid with image" do
    receipt_scan = @event.receipt_scans.build
    receipt_scan.image.attach(
      io: StringIO.new("fake image"),
      filename: "receipt.jpg",
      content_type: "image/jpeg"
    )

    assert_predicate receipt_scan, :valid?
  end
end
