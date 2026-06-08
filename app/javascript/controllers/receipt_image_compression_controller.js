import { Controller } from "@hotwired/stimulus"

const COMPRESS_THRESHOLD_BYTES = 1.2 * 1024 * 1024
const MAX_COMPRESSED_BYTES = 1.8 * 1024 * 1024
const MAX_SIDE = 1800
const JPEG_QUALITY = 0.82
const SUPPORTED_TYPES = ["image/jpeg", "image/png", "image/webp"]

export default class extends Controller {
  static targets = ["file", "submit", "status", "error"]

  async submit(event) {
    if (this.submittingCompressed) return

    const file = this.fileTarget.files[0]

    if (!file || !SUPPORTED_TYPES.includes(file.type) || file.size <= COMPRESS_THRESHOLD_BYTES) {
      return
    }

    event.preventDefault()
    this.clearError()
    this.setBusy(true)

    try {
      const compressedFile = await this.compress(file)

      if (compressedFile.size > MAX_COMPRESSED_BYTES) {
        this.showError("Фото слишком большое. Попробуйте сделать снимок ближе к чеку или выбрать фото меньшего размера.")
        this.setBusy(false)
        return
      }

      this.replaceFile(compressedFile)
      this.submittingCompressed = true
      this.element.requestSubmit()
    } catch (_error) {
      this.showError("Не удалось оптимизировать фото. Попробуйте выбрать другое изображение.")
      this.setBusy(false)
    }
  }

  async compress(file) {
    const image = await this.loadImage(file)
    const { width, height } = this.scaledSize(image.width, image.height)
    const canvas = document.createElement("canvas")

    canvas.width = width
    canvas.height = height

    const context = canvas.getContext("2d")
    context.drawImage(image, 0, 0, width, height)

    const blob = await new Promise((resolve) => {
      canvas.toBlob(resolve, "image/jpeg", JPEG_QUALITY)
    })

    if (!blob) throw new Error("Image compression failed")

    return new File([blob], this.jpegFileName(file.name), { type: "image/jpeg" })
  }

  async loadImage(file) {
    if ("createImageBitmap" in window) {
      return createImageBitmap(file)
    }

    return new Promise((resolve, reject) => {
      const image = new Image()

      image.onload = () => resolve(image)
      image.onerror = reject
      image.src = URL.createObjectURL(file)
    })
  }

  scaledSize(width, height) {
    const scale = Math.min(1, MAX_SIDE / Math.max(width, height))

    return {
      width: Math.round(width * scale),
      height: Math.round(height * scale)
    }
  }

  replaceFile(file) {
    const dataTransfer = new DataTransfer()

    dataTransfer.items.add(file)
    this.fileTarget.files = dataTransfer.files
  }

  jpegFileName(fileName) {
    return fileName.replace(/\.[^.]+$/, "") + ".jpg"
  }

  setBusy(busy) {
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = busy
      this.submitTarget.value = busy ? "Оптимизируем..." : "Загрузить чек"
    }

    if (this.hasStatusTarget) {
      this.statusTarget.textContent = busy ? "Оптимизируем фото..." : ""
      this.statusTarget.classList.toggle("hidden", !busy)
    }
  }

  showError(message) {
    if (!this.hasErrorTarget) return

    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }

  clearError() {
    if (!this.hasErrorTarget) return

    this.errorTarget.textContent = ""
    this.errorTarget.classList.add("hidden")
  }
}
