import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  remove(event) {
    event.preventDefault()

    this.element.classList.add("expense-remove")

    setTimeout(() => {
      event.target.closest("form").requestSubmit()
    }, 150)
  }
}