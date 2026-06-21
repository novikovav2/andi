import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "name",
    "amount",
    "submit",
    "splitMode",
    "quantityFields",
    "participantCheckbox",
    "quantityRow",
    "weightInput",
    "weightFill",
    "weightValue",
    "weightTotal"
  ]

  connect() {
    this.updateButton()
    this.updateSplitMode()
    this.updateQuantityRows()
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
    this.updateQuantityRows()
  }

  updateQuantityRows() {
    if (!this.hasQuantityRowTarget) return

    const selectedParticipantIds = new Set(
      this.participantCheckboxTargets
        .filter((checkbox) => checkbox.checked)
        .map((checkbox) => checkbox.dataset.participantId)
    )

    this.quantityRowTargets.forEach((row) => {
      const selected = selectedParticipantIds.has(row.dataset.participantId)
      row.hidden = !selected

      const input = row.querySelector(".expense-share-weight-input")
      if (selected && input && input.value.trim().length === 0) {
        input.value = "1"
      }
    })

    this.updateShareBars()
  }

  updateShareBars() {
    if (!this.hasQuantityRowTarget) return

    const visibleRows = this.quantityRowTargets.filter((row) => !row.hidden)
    const values = visibleRows.map((row) => this.rowWeight(row))
    const max = Math.max(0, ...values)
    const total = values.reduce((sum, value) => sum + value, 0)

    visibleRows.forEach((row) => {
      const value = this.rowWeight(row)
      const width = max > 0 ? (value / max) * 100 : 0
      const fill = row.querySelector(".expense-share-weight-fill")
      const label = row.querySelector(".expense-share-weight-value")

      if (fill) fill.style.width = `${this.formatNumber(width)}%`
      if (label) label.textContent = this.formatNumber(value)
    })

    if (this.hasWeightTotalTarget) {
      this.weightTotalTarget.textContent = `Всего: ${this.formatNumber(total)} ${this.unitLabel(total)}`
    }
  }

  incrementWeight(event) {
    this.changeWeight(event, 1)
  }

  decrementWeight(event) {
    this.changeWeight(event, -1)
  }

  changeWeight(event, delta) {
    const row = event.currentTarget.closest(".expense-share-weight-row")
    if (!row) return

    const input = row.querySelector(".expense-share-weight-input")
    if (!input) return

    const currentValue = this.inputNumber(input)
    const nextValue = Math.max(0, currentValue + delta)
    input.value = this.formatNumber(nextValue)

    this.updateShareBars()
  }

  rowWeight(row) {
    const input = row.querySelector(".expense-share-weight-input")
    if (!input) return 0

    const value = this.inputNumber(input)
    return Number.isFinite(value) && value > 0 ? value : 0
  }

  inputNumber(input) {
    const value = parseFloat(input.value.trim().replace(",", "."))
    return Number.isFinite(value) ? value : 0
  }

  formatNumber(value) {
    if (Math.abs(value - Math.round(value)) < 0.000001) return `${Math.round(value)}`

    return value
      .toFixed(2)
      .replace(/\.?0+$/, "")
  }

  unitLabel(value) {
    if (Math.abs(value - Math.round(value)) > 0.000001) return "единицы"

    const number = Math.round(value)
    const lastTwoDigits = number % 100
    if (lastTwoDigits >= 11 && lastTwoDigits <= 14) return "единиц"

    switch (number % 10) {
      case 1:
        return "единица"
      case 2:
      case 3:
      case 4:
        return "единицы"
      default:
        return "единиц"
    }
  }
}
