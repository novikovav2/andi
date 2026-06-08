import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "delayed"]
  static values = {
    delay: Number,
    maxDuration: Number,
    startedAt: String
  }

  connect() {
    const remainingTime = this.remainingTime()

    if (remainingTime !== null && remainingTime <= 0) {
      this.showDelayed()
      return
    }

    const delay = this.delayValue || 3000
    const timeout = remainingTime === null ? delay : Math.min(delay, remainingTime)

    this.timeout = setTimeout(() => {
      if (this.remainingTime() !== null && this.remainingTime() <= 0) {
        this.showDelayed()
        return
      }

      window.location.reload()
    }, timeout)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  remainingTime() {
    if (!this.hasStartedAtValue || !this.hasMaxDurationValue) return null

    const startedAt = Date.parse(this.startedAtValue)

    if (Number.isNaN(startedAt)) return null

    return this.maxDurationValue - (Date.now() - startedAt)
  }

  showDelayed() {
    if (this.hasStatusTarget) {
      this.statusTarget.classList.add("hidden")
    }

    if (this.hasDelayedTarget) {
      this.delayedTarget.classList.remove("hidden")
    }
  }
}
