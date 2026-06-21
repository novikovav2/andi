import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["name", "amount", "submit", "splitMode", "quantityFields"]

  connect() {
    this.updateButton()
    this.updateSplitMode()
  }

  updateButton() {
    if (!this.hasNameTarget || !this.hasAmountTarget || !this.hasSubmitTarget) return

    const name = this.nameTarget.value.trim()
    const amount = this.amountTarget.value.trim()

    const valid =
        name.length > 0 &&
        amount.length > 0 &&
        parseFloat(amount) > 0

    this.submitTarget.disabled = !valid
  }

  updateSplitMode() {
    if (!this.hasQuantityFieldsTarget) return

    const quantityMode = this.splitModeTargets.some((target) => {
      return target.checked && target.value === "quantity"
    })

    this.quantityFieldsTarget.hidden = !quantityMode
  }
}
