module ReceiptScansHelper
  def receipt_scan_status_label(receipt_scan)
    case receipt_scan.status
    when "pending", "processing"
      "Распознаётся"
    when "ready"
      "Распознан"
    when "failed"
      "Ошибка распознавания"
    else
      receipt_scan.status
    end
  end

  def receipt_scan_image_available?(receipt_scan)
    return false unless receipt_scan

    receipt_scan.image.attached? && receipt_scan.image_purged_at.blank?
  end

  def receipt_scan_image_path(receipt_scan)
    return unless receipt_scan_image_available?(receipt_scan)

    rails_blob_path(receipt_scan.image, disposition: "inline")
  end

  def receipt_scan_uploaded_at(receipt_scan)
    "#{l(receipt_scan.created_at.to_date, format: :long)} в #{receipt_scan.created_at.strftime('%H:%M')}"
  end
end
