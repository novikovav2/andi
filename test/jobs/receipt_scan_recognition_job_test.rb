require "test_helper"

class ReceiptScanRecognitionJobTest < ActiveJob::TestCase
  setup do
    @event = Event.create!(title: "Чек", status: "draft", organizer_token: "receipt-job-test-token")
    @receipt_scan = @event.receipt_scans.build
    @receipt_scan.image.attach(
      io: Rails.root.join("test/fixtures/files/receipt.jpg").open,
      filename: "receipt.jpg",
      content_type: "image/jpeg"
    )
    @receipt_scan.save!
  end

  test "marks receipt scan as ready when recognition succeeds" do
    with_receipt_recognition_service(successful_recognition_service) do
      ReceiptScanRecognitionJob.perform_now(@receipt_scan.id)
    end

    @receipt_scan.reload

    assert_predicate @receipt_scan, :ready?
    assert_nil @receipt_scan.error
    assert_equal "Тестовый магазин", @receipt_scan.raw_result["store"]
    assert_equal "Хлеб", @receipt_scan.raw_result["items"].first["title"]
    assert_equal 1, @receipt_scan.recognized_items_count
    assert_operator @receipt_scan.processing_time_ms, :>=, 0
  end

  test "marks receipt scan as failed when recognition fails" do
    with_receipt_recognition_service(failing_recognition_service) do
      ReceiptScanRecognitionJob.perform_now(@receipt_scan.id)
    end

    @receipt_scan.reload

    assert_predicate @receipt_scan, :failed?
    assert_equal "OCR временно недоступен", @receipt_scan.error
  end

  private

  def with_receipt_recognition_service(service_class)
    original_service = ReceiptRecognitionService
    Object.send(:remove_const, :ReceiptRecognitionService)
    Object.const_set(:ReceiptRecognitionService, service_class)

    yield
  ensure
    Object.send(:remove_const, :ReceiptRecognitionService)
    Object.const_set(:ReceiptRecognitionService, original_service)
  end

  def successful_recognition_service
    Class.new do
      def initialize(_receipt_scan)
      end

      def call
        {
          "store" => "Тестовый магазин",
          "total" => "1200.00",
          "items" => [
            { "title" => "Хлеб", "amount" => "120.00" }
          ]
        }
      end
    end
  end

  def failing_recognition_service
    Class.new do
      def initialize(_receipt_scan)
      end

      def call
        raise "OCR временно недоступен"
      end
    end
  end
end
