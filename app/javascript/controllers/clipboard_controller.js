import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    text: String
  }

  async copy(event) {
    event.preventDefault()

    try {
      await navigator.clipboard.writeText(this.textValue)
      this.showToast("Ссылка скопирована")
    } catch {
      this.fallbackCopy()
      this.showToast("Ссылка скопирована")
    }
  }

  fallbackCopy() {
    const input = document.createElement("input")
    input.value = this.textValue
    document.body.appendChild(input)
    input.select()
    document.execCommand("copy")
    input.remove()
  }

  showToast(message) {
    const flash = document.getElementById("flash")
    if (!flash) return

    flash.innerHTML = `
      <div class="fixed top-4 left-1/2 -translate-x-1/2 z-50 rounded-full bg-slate-900 text-white px-4 py-2 text-sm shadow-lg">
        ${message}
      </div>
    `

    setTimeout(() => {
      flash.innerHTML = ""
    }, 1800)
  }
}