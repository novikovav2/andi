class ReceiptScanRecognitionJob < ApplicationJob
  queue_as :default

  def perform(receipt_scan_id)
    receipt_scan = ReceiptScan.find(receipt_scan_id)
    receipt_scan.update!(status: "processing", error: nil)

    result = ReceiptRecognitionService.new(receipt_scan).call

    receipt_scan.update!(
      status: "ready",
      raw_result: result,
      error: nil
    )
  rescue => e
    receipt_scan&.update!(
      status: "failed",
      error: e.message
    )
  end
end
