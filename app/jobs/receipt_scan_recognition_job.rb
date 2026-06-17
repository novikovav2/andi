class ReceiptScanRecognitionJob < ApplicationJob
  queue_as :default

  def perform(receipt_scan_id)
    receipt_scan = ReceiptScan.find(receipt_scan_id)
    receipt_scan.update!(status: "processing", error: nil)
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    result = ReceiptRecognitionService.new(receipt_scan).call
    processing_time_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

    receipt_scan.update!(
      status: "ready",
      raw_result: result,
      error: nil,
      recognized_items_count: Array(result["items"]).count,
      processing_time_ms:
    )
  rescue => e
    Rails.logger.warn(
      "[ReceiptScanRecognitionJob] receipt_scan_id=#{receipt_scan_id} failed: #{e.class}: #{e.message}"
    )

    receipt_scan&.update!(
      status: "failed",
      error: e.message
    )
  end
end
