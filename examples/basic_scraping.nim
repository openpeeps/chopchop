import std/[asyncdispatch, strutils]
import ../src/chopchop

when isMainModule:
  proc main() {.async.} =
    let browser = await launchBrowser()
    try:
      let page = await browser.newPage()

      echo "=== Navigation ==="
      await page.goto("https://example.com")
      echo "Title: ", await page.title()
      echo "URL:  ", await page.url()

      echo "\n=== DOM Querying ==="
      let h1 = await page.querySelector("h1")
      if h1 != nil:
        echo "H1 text: ", await h1.innerText()

      let links = await page.querySelectorAll("a")
      echo "Links found: ", links.len
      for i, link in links:
        echo "  [$1] \"$2\" -> $3" % [
          $i, await link.innerText(), await link.getAttribute("href")
        ]

      echo "\n=== Evaluate ==="
      let docTitle = await page.evaluate("document.title")
      echo "Document title via evaluate kind: ", docTitle.kind

      echo "\n=== Page Content ==="
      let html = await page.content()
      echo "Full HTML length: ", html.len, " chars"

      echo "\n=== Screenshot ==="
      let ss = await page.screenshot()
      echo "Base64 data length: ", ss.len, " chars"

    finally:
      await browser.close()

  waitFor main()
