import std/[asyncdispatch, json]
import ../src/chopchop

when isMainModule:
  proc main() {.async.} =
    let browser = await launchBrowser()
    try:
      let page = await browser.newPage()
      await page.goto("https://example.com")

      echo "=== Injecting Test Elements ==="
      discard await page.evaluate("""
        document.body.innerHTML = `
          <div id="playground">
            <input id="name" placeholder="Name">
            <input id="email" type="email" placeholder="Email">
            <textarea id="message" rows="3"></textarea>
            <select id="country">
              <option value="">Select</option>
              <option value="us">United States</option>
              <option value="uk">United Kingdom</option>
              <option value="ca">Canada</option>
            </select>
            <button id="submit">Submit</button>
            <p id="output"></p>
          </div>
        `
      """)

      echo "\n=== Fill Inputs ==="
      await page.locator("#name").fill("George Lemon")
      await page.locator("#email").fill("george@example.com")
      let nameVal = await page.evaluate("document.querySelector('#name').value")
      let emailVal = await page.evaluate("document.querySelector('#email').value")
      echo "Name:  ", $nameVal
      echo "Email: ", $emailVal

      echo "\n=== Type Text ==="
      await page.locator("#message").typeText("Hello! This is chopchop.")
      let msgVal = await page.evaluate("document.querySelector('#message').value")
      echo "Message: ", $msgVal

      echo "\n=== Select Option ==="
      await page.locator("#country").selectOption("uk")
      let countryVal = await page.evaluate("document.querySelector('#country').value")
      echo "Country: ", $countryVal

      echo "\n=== Click ==="
      await page.locator("#submit").click()
      echo "Button clicked"

      echo "\n=== Hover ==="
      await page.locator("#submit").hover()
      echo "Button hovered"

    finally:
      await browser.close()

  waitFor main()
