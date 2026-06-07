import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox"]

  selectAll() {
    this.setChecked(true)
  }

  selectNone() {
    this.setChecked(false)
  }

  setChecked(checked) {
    this.checkboxTargets.forEach((checkbox) => {
      checkbox.checked = checked
    })
  }
}
