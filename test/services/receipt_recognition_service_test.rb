require "test_helper"

class ReceiptRecognitionServiceTest < ActiveSupport::TestCase
  setup do
    @event = Event.create!(title: "Чек", status: "draft", organizer_token: "receipt-service-test-token")
    @receipt_scan = @event.receipt_scans.build
    @receipt_scan.image.attach(
      io: Rails.root.join("test/fixtures/files/receipt.jpg").open,
      filename: "receipt.jpg",
      content_type: "image/jpeg"
    )
    @receipt_scan.save!
  end

  test "recognizes text with Yandex Vision and parses YandexGPT response" do
    result = with_yandex_env do
      ReceiptRecognitionService.new(
        @receipt_scan,
        http_client: fake_http_client(
          ocr_response("ООО Тестовый магазин\nХлеб 120.00\nСыр 350.00\nИтого 1200.00"),
          gpt_response({
            store: "Тестовый магазин",
            date: "2026-06-07",
            total: "1200.00",
            items: [
              { title: "Хлеб", amount: "120.00" },
              { title: "Сыр", amount: "350.00" }
            ]
          })
        )
      ).call
    end

    assert_equal "Тестовый магазин", result["store"]
    assert_equal "2026-06-07", result["date"]
    assert_equal "1200.0", result["total"]
    assert_equal [
      { "title" => "Хлеб", "amount" => "120.0" },
      { "title" => "Сыр", "amount" => "350.0" }
    ], result["items"]
  end

  test "raises clear error for OCR failure" do
    error = assert_raises(RuntimeError) do
      with_yandex_env do
        ReceiptRecognitionService.new(
          @receipt_scan,
          http_client: fake_http_client(fake_response(500, { message: "OCR unavailable" }.to_json))
        ).call
      end
    end

    assert_equal "Ошибка Yandex Vision OCR: OCR unavailable", error.message
  end

  test "raises clear error for invalid JSON from YandexGPT" do
    error = assert_raises(RuntimeError) do
      with_yandex_env do
        ReceiptRecognitionService.new(
          @receipt_scan,
          http_client: fake_http_client(
            ocr_response("Хлеб 120.00"),
            gpt_text_response("not json")
          )
        ).call
      end
    end

    assert_equal "YandexGPT вернул некорректный JSON", error.message
  end

  test "raises clear error without Yandex env" do
    without_yandex_env do
      error = assert_raises(RuntimeError) do
        ReceiptRecognitionService.new(
          @receipt_scan,
          http_client: fake_http_client(ocr_response("Хлеб 120.00"))
        ).call
      end

      assert_equal "YANDEX_CLOUD_IAM_TOKEN не задан", error.message
    end
  end

  test "normalizes comma amounts" do
    result = with_yandex_env do
      ReceiptRecognitionService.new(
        @receipt_scan,
        http_client: fake_http_client(
          ocr_response("Молоко 120,40\nИтого 1 200,50"),
          gpt_response({
            total: "1 200,50",
            items: [
              { title: "Молоко", amount: "120,40" }
            ]
          })
        )
      ).call
    end

    assert_equal "1200.5", result["total"]
    assert_equal "120.4", result["items"].first["amount"]
  end

  test "removes blank items" do
    result = with_yandex_env do
      ReceiptRecognitionService.new(
        @receipt_scan,
        http_client: fake_http_client(
          ocr_response("Хлеб 90.00"),
          gpt_response({
            total: "120.00",
            items: [
              { title: "", amount: "120.00" },
              { title: "Сыр", amount: "" },
              { title: "Хлеб", amount: "90.00" }
            ]
          })
        )
      ).call
    end

    assert_equal [ { "title" => "Хлеб", "amount" => "90.0" } ], result["items"]
  end

  test "raises clear error for empty items" do
    error = assert_raises(RuntimeError) do
      with_yandex_env do
        ReceiptRecognitionService.new(
          @receipt_scan,
          http_client: fake_http_client(
            ocr_response("Итого 120.00"),
            gpt_response({ items: [] })
          )
        ).call
      end
    end

    assert_equal "YandexGPT не нашёл позиции в чеке", error.message
  end

  test "raises clear error for unsupported content type" do
    receipt_scan = @event.receipt_scans.build
    receipt_scan.image.attach(
      io: StringIO.new("pdf"),
      filename: "receipt.pdf",
      content_type: "application/pdf"
    )
    receipt_scan.save!

    error = assert_raises(RuntimeError) do
      with_yandex_env do
        ReceiptRecognitionService.new(receipt_scan, http_client: fake_http_client).call
      end
    end

    assert_equal "Неподдерживаемый формат изображения: application/pdf", error.message
  end

  private

  def with_yandex_env
    original_iam_token = ENV["YANDEX_CLOUD_IAM_TOKEN"]
    original_folder_id = ENV["YANDEX_CLOUD_FOLDER_ID"]
    ENV["YANDEX_CLOUD_IAM_TOKEN"] = "test-iam-token"
    ENV["YANDEX_CLOUD_FOLDER_ID"] = "test-folder-id"

    yield
  ensure
    restore_env("YANDEX_CLOUD_IAM_TOKEN", original_iam_token)
    restore_env("YANDEX_CLOUD_FOLDER_ID", original_folder_id)
  end

  def without_yandex_env
    original_iam_token = ENV["YANDEX_CLOUD_IAM_TOKEN"]
    original_folder_id = ENV["YANDEX_CLOUD_FOLDER_ID"]
    ENV.delete("YANDEX_CLOUD_IAM_TOKEN")
    ENV.delete("YANDEX_CLOUD_FOLDER_ID")

    yield
  ensure
    restore_env("YANDEX_CLOUD_IAM_TOKEN", original_iam_token)
    restore_env("YANDEX_CLOUD_FOLDER_ID", original_folder_id)
  end

  def restore_env(key, value)
    if value
      ENV[key] = value
    else
      ENV.delete(key)
    end
  end

  def fake_http_client(*responses)
    response_queue = responses.dup

    Class.new do
      define_method(:initialize) do |queue|
        @queue = queue
      end

      def start(_hostname, _port, use_ssl:)
        raise "Yandex API request must use SSL" unless use_ssl

        yield self
      end

      def request(_request)
        @queue.shift || raise("unexpected request")
      end
    end.new(response_queue)
  end

  def ocr_response(text)
    fake_response(200, {
      result: {
        textAnnotation: {
          fullText: text
        }
      }
    }.to_json)
  end

  def gpt_response(payload)
    gpt_text_response(payload.to_json)
  end

  def gpt_text_response(text)
    fake_response(200, {
      result: {
        alternatives: [
          {
            message: {
              text:
            }
          }
        ]
      }
    }.to_json)
  end

  def fake_response(code, body)
    Struct.new(:code, :body).new(code.to_s, body)
  end
end
