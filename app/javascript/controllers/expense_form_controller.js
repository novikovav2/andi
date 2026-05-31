import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["name", "amount", "submit"]

  connect() {
    this.updateButton()
  }

  updateButton() {
    const name = this.nameTarget.value.trim()
    const amount = this.amountTarget.value.trim()

    const valid =
        name.length > 0 &&
        amount.length > 0 &&
        parseFloat(amount) > 0

    this.submitTarget.disabled = !valid
  }
}