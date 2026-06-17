import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "selected"]

  update() {
    const count = this.inputTarget.files.length

    if (count === 0) {
      this.selectedTarget.textContent = "Файлы не выбраны"
    } else if (count === 1) {
      this.selectedTarget.textContent = "Выбрано фото: 1"
    } else {
      this.selectedTarget.textContent = `Выбрано фото: ${count}`
    }
  }
}
