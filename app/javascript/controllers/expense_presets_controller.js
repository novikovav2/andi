import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["title"]

  set(event) {
    event.preventDefault()

    this.titleTarget.value = event.currentTarget.dataset.expensePresetsTitle
    this.titleTarget.focus()
    this.titleTarget.dispatchEvent(new Event("input", { bubbles: true }))
  }
}