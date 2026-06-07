require "base64"
require "json"
require "net/http"
require "uri"

class ReceiptRecognitionService
  SUPPORTED_CONTENT_TYPES = %w[
    image/jpeg
    image/png
    image/webp
    image/heic
    image/heif
  ].freeze

  OCR_URL = "https://ocr.api.cloud.yandex.net/ocr/v1/recognizeText"
  GPT_URL = "https://llm.api.cloud.yandex.net/foundationModels/v1/completion"
  GPT_MODEL = "yandexgpt-lite"

  def initialize(receipt_scan, http_client: Net::HTTP)
    @receipt_scan = receipt_scan
    @http_client = http_client
  end

  def call
    validate_image!
    validate_credentials!

    receipt_text = recognize_text
    raise "Yandex Vision не распознал текст чека" if receipt_text.blank?

    normalize_result(parse_gpt_response(structure_receipt(receipt_text)))
  rescue JSON::ParserError
    raise "YandexGPT вернул некорректный JSON"
  end

  private

  attr_reader :receipt_scan, :http_client

  def validate_image!
    raise "Добавьте фото чека" unless receipt_scan.image.attached?

    return if SUPPORTED_CONTENT_TYPES.include?(content_type)

    raise "Неподдерживаемый формат изображения: #{content_type}"
  end

  def validate_credentials!
    raise "YANDEX_CLOUD_IAM_TOKEN не задан" if iam_token.blank?
    raise "YANDEX_CLOUD_FOLDER_ID не задан" if folder_id.blank?
  end

  def recognize_text
    response = post_json(
      OCR_URL,
      {
        mimeType: content_type,
        languageCodes: [ "ru", "en" ],
        model: "page",
        content: Base64.strict_encode64(receipt_scan.image.download)
      }
    )

    raise "Ошибка Yandex Vision OCR: #{response_error(response)}" unless response_success?(response)

    extract_ocr_text(JSON.parse(response.body))
  rescue JSON::ParserError
    raise "Yandex Vision OCR вернул некорректный JSON"
  end

  def structure_receipt(receipt_text)
    response = post_json(
      GPT_URL,
      {
        modelUri: "gpt://#{folder_id}/#{GPT_MODEL}/latest",
        completionOptions: {
          stream: false,
          temperature: 0,
          maxTokens: 1200
        },
        messages: [
          {
            role: "user",
            text: recognition_prompt(receipt_text)
          }
        ]
      }
    )

    raise "Ошибка YandexGPT: #{response_error(response)}" unless response_success?(response)

    response
  end

  def post_json(url, payload)
    uri = URI(url)
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{iam_token}"
    request["x-folder-id"] = "#{folder_id}"
    request["Content-Type"] = "application/json"
    request.body = payload.to_json

    http_client.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(request)
    end
  rescue StandardError => e
    raise "Ошибка Yandex Cloud: #{e.message}"
  end

  def response_success?(response)
    response.code.to_i.between?(200, 299)
  end

  def response_error(response)
    body = JSON.parse(response.body)
    body["message"] || body["error"] || response.body
  rescue JSON::ParserError
    response.body
  end

  def extract_ocr_text(response)
    text = response.dig("result", "textAnnotation", "fullText")
    return text.to_s.strip if text.present?

    pages = Array(response.dig("result", "textAnnotation", "pages"))
    pages.flat_map { |page| extract_page_lines(page) }.join("\n").strip
  end

  def extract_page_lines(page)
    Array(page["blocks"]).flat_map do |block|
      Array(block["lines"]).map { |line| extract_line_text(line) }
    end
  end

  def extract_line_text(line)
    return line["text"].to_s.strip if line["text"].present?

    Array(line["words"]).map { |word| word["text"].to_s }.join(" ").strip
  end

  def parse_gpt_response(response)
    body = JSON.parse(response.body)
    content = body.dig("result", "alternatives", 0, "message", "text")

    raise JSON::ParserError, "empty response" if content.to_s.strip.blank?

    JSON.parse(strip_json_fence(content))
  end

  def strip_json_fence(content)
    content.to_s.strip
           .sub(/\A```(?:json)?\s*/i, "")
           .sub(/\s*```\z/, "")
  end

  def recognition_prompt(receipt_text)
    <<~PROMPT.squish
      Ниже текст кассового чека после OCR. Преобразуй его в строго валидный JSON без markdown:
      {"store":"...","date":"...","total":"1234.56","items":[{"title":"...","amount":"123.45"}]}.
      В items добавляй только товары или услуги с понятной конечной ценой.
      Не включай строки количества, скидок, промежуточных итогов и позиции без ясной цены.
      Суммы возвращай строками с точкой как десятичным разделителем.
      Текст чека: #{receipt_text}
    PROMPT
  end

  def normalize_result(result)
    normalized = {
      "store" => result["store"].to_s.strip.presence,
      "date" => result["date"].to_s.strip.presence,
      "total" => normalize_amount(result["total"]),
      "items" => normalize_items(result["items"])
    }

    raise "YandexGPT не нашёл позиции в чеке" if normalized["items"].empty?

    normalized
  end

  def normalize_items(items)
    Array(items).filter_map do |item|
      title = item["title"].to_s.strip
      amount = normalize_amount(item["amount"])

      next if title.blank? || amount.blank?

      { "title" => title, "amount" => amount }
    end
  end

  def normalize_amount(amount)
    normalized = amount.to_s.strip.tr(",", ".").gsub(/[^\d.]/, "")
    return nil if normalized.blank?

    BigDecimal(normalized).to_s("F")
  rescue ArgumentError
    nil
  end

  def content_type
    receipt_scan.image.blob.content_type.to_s
  end

  def iam_token
    ENV["YANDEX_CLOUD_IAM_TOKEN"].to_s.strip
  end

  def folder_id
    ENV["YANDEX_CLOUD_FOLDER_ID"].to_s.strip
  end
end
