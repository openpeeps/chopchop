import std/[asyncdispatch]
import ../src/chopchop

when isMainModule:
  proc main() {.async.} =
    let browser = await launchBrowser()
    try:
      echo "=== Browser Context Isolation ==="
      let ctx = await browser.newContext()
      let ctxPage = await ctx.newPage()
      await ctxPage.goto("https://example.com")
      await ctxPage.setCookie(Cookie(name: "secret", value: "isolated-data"))
      echo "Context cookies: ", (await ctxPage.cookies()).len
      await ctx.close()

      let defaultPage = await browser.newPage()
      await defaultPage.goto("https://example.com")
      echo "Default page cookies: ", (await defaultPage.cookies()).len

      echo "\n=== Device Emulation ==="
      let emuPage = await browser.newPage()
      await emuPage.setViewport(375, 812, deviceScaleFactor = 3.0, isMobile = true)
      await emuPage.setUserAgent("Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X)")
      await emuPage.goto("https://example.com")
      echo "Mobile viewport: 375x812 @3x"

      let ss = await emuPage.screenshot()
      echo "Mobile screenshot: ", ss.len, " chars"

      echo "\n=== Geolocation ==="
      await emuPage.setGeolocation(48.8566, 2.3522, 100)
      echo "Geolocation set to Paris"

    finally:
      await browser.close()

  waitFor main()
