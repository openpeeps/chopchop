# A browser automation app for launching and
# controlling Chrome via DevTools Protocol
#
# (c) 2026 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/chopchop

import std/[asyncdispatch]
import chopchop/[types, element, page, browser, context, locator]
export types, element, page, browser, context, locator

when isMainModule:
  proc demoLocator(page: page.Page) {.async.} =
    echo "Navigating to https://example.com ..."
    await page.goto("https://example.com")

    echo "\n=== Locator API: CSS selector ==="
    let h1 = page.locator("h1")
    echo "h1 count: ", await h1.count()
    echo "h1 text:  ", await h1.innerText()

    let link = page.locator("a")
    echo "link count: ", await link.count()
    echo "link href:  ", await link.getAttribute("href")

    echo "\n=== Locator API: filter by text ==="
    let filtered = page.locator("a").filter(hasText = "Learn")
    echo "filtered count: ", await filtered.count()
    echo "filtered href:  ", await filtered.getAttribute("href")

    echo "\n=== Locator API: first / last / nth ==="
    let items = page.locator("p, a")
    echo "total elements: ", await items.count()
    echo "first text: ", await items.first().innerText()
    echo "last href:  ", await items.last().getAttribute("href")

    echo "\n=== Locator API: nested locator ==="
    let body = page.locator("body")
    let bodyP = body.locator("p")
    echo "body > p text: ", await bodyP.innerText()

  proc demo(page: page.Page) {.async.} =
    echo "=== Phase 1: Basic navigation ==="
    echo "Navigating to https://example.com ..."
    await page.goto("https://example.com")

    echo "Title: ", await page.title()
    echo "URL:  ", await page.url()

    let heading = await page.querySelector("h1")
    if heading != nil:
      echo "H1 text: ", await heading.innerText()

    let links = await page.querySelectorAll("a")
    echo "Links found: ", links.len
    for i, link in links:
      let href = await link.getAttribute("href")
      let text = await link.innerText()
      echo "  [" & $i & "] \"" & text & "\" -> " & href

    let html = await page.content()
    echo "Page HTML length: ", html.len, " chars"

    let ss = await page.screenshot()
    echo "Screenshot data length: ", ss.len, " chars"

    echo "\n=== Phase 2: evaluate & back/forward ==="
    let title2 = await page.evaluate("document.title")
    echo "evaluate title kind: ", title2.kind

    echo "\n=== Phase 2: navigation via evaluate ==="
    discard await page.evaluate("window.location.href = 'https://example.com/'")
    await page.waitForNavigation(WaitForNavigationOptions(
        waitUntil: NavigationWaitUntil.DOMContentLoaded))
    echo "Navigated back to - URL: ", await page.url()
    echo "Navigated back to - Title: ", await page.title()

    echo "\n=== Phase 2: viewport & screenshot ==="
    await page.setViewport(800, 600)
    let ss2 = await page.screenshot()
    echo "Viewport 800x600 screenshot: ", ss2.len, " chars"

    echo "\n=== Phase 2: cookies ==="
    await page.setCookie(Cookie(name: "mykey", value: "myvalue"))
    echo "Cookies after setCookie: ", (await page.cookies()).len
    await page.deleteCookie("mykey")
    echo "Cookies after deleteCookie: ", (await page.cookies()).len
    await page.setCookie(Cookie(name: "ck1", value: "v1"))
    await page.setCookie(Cookie(name: "ck2", value: "v2"))
    echo "Cookies count before clear: ", (await page.cookies()).len
    await page.clearCookies()
    echo "Cookies after clear: ", (await page.cookies()).len

    echo "\n=== Phase 2: localStorage ==="
    echo "localStorage initial: ", await page.localStorage("testKey")
    await page.setLocalStorage("testKey", "testValue")
    echo "localStorage after set: ", await page.localStorage("testKey")

  proc demoConsoleHandler(page: page.Page) {.async.} =
    echo "\n=== Phase 2: console messages ==="
    var msgs: seq[ConsoleMessage] = @[]
    await page.onConsole(proc(msg: ConsoleMessage): Future[void] {.closure, async.} =
      msgs.add(msg)
    )
    await page.goto("https://example.com")
    discard await page.evaluate("console.log('hello from chopchop')")
    echo "Console messages captured: ", msgs.len
    for m in msgs:
      echo "  level: ", m.level, " text: ", m.text

  proc demoInitScript(page: page.Page) {.async.} =
    echo "\n=== Phase 2: addInitScript ==="
    discard await page.addInitScript("window.chopchopTest = 'injected';")
    await page.goto("https://example.com")
    let val = await page.evaluate("window.chopchopTest")
    echo "Init script injected value kind: ", val.kind

  proc demoBrowserContext() {.async.} =
    echo "\n=== Phase 2: BrowserContext isolation ==="
    let browser = await launchBrowser()
    try:
      let ctx = await browser.newContext()
      let page2 = await ctx.newPage()
      await page2.goto("https://httpbin.org/cookies/set?test=hello")
      echo "Context cookies: ", (await page2.cookies()).len
      await ctx.close()

      let page3 = await browser.newPage()
      await page3.goto("https://example.com")
      echo "Default page cookies: ", (await page3.cookies()).len
    finally:
      await browser.close()

  proc main() {.async.} =
    let browser = await launchBrowser()
    try:
      let page1 = await browser.newPage()
      await demoLocator(page1)

      let page2 = await browser.newPage()
      await demo(page2)

      let page3 = await browser.newPage()
      await demoConsoleHandler(page3)

      let page4 = await browser.newPage()
      await demoInitScript(page4)

      await demoBrowserContext()

      echo "\nDone. Closing browser."
    finally:
      await browser.close()

  waitFor main()
