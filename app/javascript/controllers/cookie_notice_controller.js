import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  accept() {
    const maxAge = 60 * 60 * 24 * 365

    document.cookie = `andi_cookie_notice_accepted=true; path=/; max-age=${maxAge}; SameSite=Lax`
    this.element.remove()
  }
}
