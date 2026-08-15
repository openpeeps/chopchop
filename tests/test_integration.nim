## Integration tests that exercise chopchop against a real Chrome instance.
## Each test drives the full stack: the powpow WebSocket transport, the
## openparser typed-JSON layer and the high-level API.

import std/[unittest, asyncdispatch, json, strutils]
import ../src/chopchop

var browser: Browser

proc getBrowser(): Browser =
  if browser.isNil:
    browser = waitFor launchBrowser()
  browser

proc newPage(): Page =
  let b = getBrowser()
  waitFor b.newPage()

suite "navigation":
  test "goto loads title and url":
    let page = newPage()
    waitFor page.goto("https://example.com")
    check (waitFor page.title()) == "Example Domain"
    check (waitFor page.url()).startsWith("https://example.com")

suite "dom querying":
  test "querySelector finds h1":
    let page = newPage()
    waitFor page.goto("https://example.com")
    let h1 = waitFor page.querySelector("h1")
    check h1 != nil
    check (waitFor h1.innerText()) == "Example Domain"

  test "querySelectorAll returns links with hrefs":
    let page = newPage()
    waitFor page.goto("https://example.com")
    let links = waitFor page.querySelectorAll("a")
    check links.len > 0
    check (waitFor links[0].getAttribute("href")).startsWith("https://")

  test "querySelector missing element returns nil":
    let page = newPage()
    waitFor page.goto("https://example.com")
    check (waitFor page.querySelector("#does-not-exist")) == nil

suite "evaluation":
  test "evaluate arithmetic":
    let page = newPage()
    waitFor page.goto("https://example.com")
    let r = waitFor page.evaluate("1 + 2")
    check r.contains("value")
    check r["value"].getInt() == 3

suite "content and screenshot":
  test "content returns rendered html":
    let page = newPage()
    waitFor page.goto("https://example.com")
    let html = waitFor page.content()
    check html.len > 0
    check html.contains("Example Domain")

  test "screenshot returns base64 data":
    let page = newPage()
    waitFor page.goto("https://example.com")
    let ss = waitFor page.screenshot()
    check ss.len > 0

suite "cookies":
  test "set, get and delete a cookie":
    let page = newPage()
    waitFor page.goto("https://example.com")
    waitFor page.setCookie(Cookie(name: "k", value: "v"))
    let cs = waitFor page.cookies()
    check cs.len == 1
    check cs[0].name == "k"
    check cs[0].value == "v"
    waitFor page.deleteCookie("k")
    check (waitFor page.cookies()).len == 0

  test "clear all cookies":
    let page = newPage()
    waitFor page.goto("https://example.com")
    waitFor page.setCookie(Cookie(name: "a", value: "1"))
    waitFor page.setCookie(Cookie(name: "b", value: "2"))
    check (waitFor page.cookies()).len == 2
    waitFor page.clearCookies()
    check (waitFor page.cookies()).len == 0

suite "storage":
  test "localStorage set and get":
    let page = newPage()
    waitFor page.goto("https://example.com")
    waitFor page.setLocalStorage("k", "v")
    check (waitFor page.localStorage("k")) == "v"

  test "sessionStorage set and get":
    let page = newPage()
    waitFor page.goto("https://example.com")
    waitFor page.setSessionStorage("k", "v")
    check (waitFor page.sessionStorage("k")) == "v"

suite "console and init script":
  test "capture console messages":
    let page = newPage()
    var msgs: seq[ConsoleMessage]
    waitFor page.onConsole(proc(m: ConsoleMessage): Future[void] {.closure, async.} =
      msgs.add(m))
    waitFor page.goto("https://example.com")
    discard waitFor page.evaluate("console.log('hello from test')")
    waitFor sleepAsync(200)
    check msgs.len > 0
    check msgs[0].text == "hello from test"

  test "addInitScript runs before page scripts":
    let page = newPage()
    discard waitFor page.addInitScript("window.__chopchopTest = 42;")
    waitFor page.goto("https://example.com")
    let r = waitFor page.evaluate("window.__chopchopTest")
    check r.contains("value")
    check r["value"].getInt() == 42

suite "device emulation":
  test "setViewport changes inner dimensions":
    let page = newPage()
    waitFor page.goto("https://example.com")
    waitFor page.setViewport(320, 480)
    waitFor sleepAsync(100)
    let rw = waitFor page.evaluate("window.innerWidth")
    let rh = waitFor page.evaluate("window.innerHeight")
    check rw.contains("value")
    check rh.contains("value")
    check rw["value"].getInt() == 320
    check rh["value"].getInt() == 480

  test "setUserAgent overrides navigator.userAgent":
    let page = newPage()
    waitFor page.goto("https://example.com")
    waitFor page.setUserAgent("chopchop-test-agent")
    waitFor sleepAsync(100)
    let r = waitFor page.evaluate("navigator.userAgent")
    check r.contains("value")
    check r["value"].getStr() == "chopchop-test-agent"

suite "browser context":
  test "context cookies are isolated":
    let b = getBrowser()
    let ctx = waitFor b.newContext()
    let page2 = waitFor ctx.newPage()
    waitFor page2.goto("https://example.com")
    waitFor page2.setCookie(Cookie(name: "ctx", value: "1"))
    check (waitFor page2.cookies()).len == 1
    let defaultPage = waitFor b.newPage()
    waitFor defaultPage.goto("https://example.com")
    check (waitFor defaultPage.cookies()).len == 0
    waitFor ctx.close()

suite "element interactions":
  test "click triggers the element handler":
    let page = newPage()
    waitFor page.goto(
        "data:text/html,<button id='b' onclick='window.__clicked=1'>Go</button>")
    let btn = waitFor page.querySelector("button")
    check btn != nil
    waitFor btn.click()
    waitFor sleepAsync(150)
    let r = waitFor page.evaluate("window.__clicked")
    check r.contains("value")
    check r["value"].getInt() == 1

  test "typeText fills an input":
    let page = newPage()
    waitFor page.goto("data:text/html,<input id='i'>")
    let input = waitFor page.querySelector("input")
    check input != nil
    waitFor input.typeText("hello")
    waitFor sleepAsync(150)
    let r = waitFor page.evaluate("document.querySelector('input').value")
    check r.contains("value")
    check r["value"].getStr() == "hello"

suite "locators":
  test "locator count, text and attribute":
    let page = newPage()
    waitFor page.goto("https://example.com")
    check (waitFor page.locator("a").count()) > 0
    check (waitFor page.locator("h1").innerText()) == "Example Domain"
    let href = waitFor page.locator("a").getAttribute("href")
    check href.startsWith("https://")

  test "waitForSelector resolves":
    let page = newPage()
    waitFor page.goto("https://example.com")
    let el = waitFor page.waitForSelector("h1")
    check el != nil

suite "cleanup":
  test "close the shared browser":
    if browser != nil:
      waitFor browser.close()
      browser = nil
