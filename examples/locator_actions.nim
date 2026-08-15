import std/[asyncdispatch]
import ../src/chopchop

when isMainModule:
  proc main() {.async.} =
    let browser = await launchBrowser()
    try:
      let page = await browser.newPage()
      await page.goto("https://example.com")

      echo "=== Locator: Count & Text ==="
      let links = page.locator("a")
      echo "Links: ", await links.count()

      let h1 = page.locator("h1")
      echo "H1: ", await h1.innerText()

      echo "\n=== Locator: Filter ==="
      let filtered = page.locator("a").filter(hasText = "Learn")
      echo "Filtered count: ", await filtered.count()
      echo "Filtered href: ", await filtered.getAttribute("href")

      echo "\n=== Locator: first / last / nth ==="
      let items = page.locator("p, a")
      echo "Total: ", await items.count()
      echo "First: ", await items.first().innerText()
      echo "Last:  href=", await items.last().getAttribute("href")

      echo "\n=== Locator: Nested ==="
      let body = page.locator("body")
      let bodyP = body.locator("p")
      echo "body > p: ", await bodyP.innerText()

      echo "\n=== Wait For Selector ==="
      let el = await page.waitForSelector("h1")
      echo "Found via waitForSelector: ", await el.innerText()

    finally:
      await browser.close()

  waitFor main()
