import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    title: String,
    message: String,
    confirmText: String,
    cancelText: String
  }

  ask(event) {
    event.preventDefault()

    this.form = event.target.closest("form")

    this.overlay = document.createElement("div")
    this.overlay.className = "confirm-overlay"

    this.overlay.innerHTML = `
      <div class="confirm-sheet">
        <div class="confirm-handle"></div>

        <h2 class="confirm-title">${this.titleValue || "Подтвердить действие?"}</h2>

        <p class="confirm-message">
          ${this.messageValue || "Это действие нельзя отменить."}
        </p>

        <div class="confirm-actions">
          <button type="button" class="confirm-cancel">
            ${this.cancelTextValue || "Отмена"}
          </button>

          <button type="button" class="confirm-delete">
            ${this.confirmTextValue || "Удалить"}
          </button>
        </div>
      </div>
    `

    document.body.appendChild(this.overlay)

    this.overlay.querySelector(".confirm-cancel").addEventListener("click", () => {
      this.close()
    })

    this.overlay.querySelector(".confirm-delete").addEventListener("click", () => {
      this.form.requestSubmit()
      this.close()
    })

    this.overlay.addEventListener("click", (e) => {
      if (e.target === this.overlay) this.close()
    })
  }

  close() {
    this.overlay?.remove()
  }
}