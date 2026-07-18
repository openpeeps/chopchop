import std/[asyncdispatch, strutils]
import ../src/chopchop

when isMainModule:
  proc main() {.async.} =
    let browser = await launchBrowser()
    try:
      let page = await browser.newPage()

      echo "=== Console Capture ==="
      var msgs: seq[ConsoleMessage] = @[]
      await page.onConsole(proc(m: ConsoleMessage): Future[void] {.closure, async.} =
        msgs.add(m)
      )
      await page.goto("https://example.com")
      discard await page.evaluate("console.log('hello from chopchop')")
      discard await page.evaluate("console.warn('this is a warning')")
      discard await page.evaluate("console.error('something went wrong')")
      echo "Messages captured: ", msgs.len
      for m in msgs:
        echo "  [$1] $2" % [m.level, m.text]

      echo "\n=== Add Init Script ==="
      let initId = await page.addInitScript("window.chopchopVersion = '0.1.0'")
      await page.goto("https://example.com")
      let v = await page.evaluate("window.chopchopVersion")
      echo "Init script value kind: ", v.kind

    finally:
      await browser.close()

  waitFor main()
