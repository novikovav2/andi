import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.timeout = setTimeout(() => {
      this.hide()
    }, 3000)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  hide() {
    this.element.classList.add("toast-hide")

    setTimeout(() => {
      this.element.remove()
    }, 300)
  }
}