import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { delay: Number }

  connect() {
    this.timeout = setTimeout(() => {
      window.location.reload()
    }, this.delayValue || 3000)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
