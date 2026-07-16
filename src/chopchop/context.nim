import std/[asyncdispatch, json]
import pkg/cdp as cdp
import types, page, browser

type
  BrowserContext* = ref object
    browser*: browser.Browser
    id*: string
    pages*: seq[page.Page]

proc newContext*(b: browser.Browser; options: BrowserContextOptions = defaultBrowserContextOptions()): Future[BrowserContext] {.async.} =
  let resp = await b.cdp.sendCommand("Target.createBrowserContext")
  let ctxId = resp["result"]["browserContextId"].getStr()
  result = BrowserContext(browser: b, id: ctxId)

proc newPage*(ctx: BrowserContext; options: NavigationOptions = defaultNavigationOptions()): Future[page.Page] {.async.} =
  let createResult = await ctx.browser.cdp.sendCommand("Target.createTarget",
      %*{"url": "about:blank", "browserContextId": ctx.id})
  let targetId = createResult["result"]["targetId"].getStr()
  let attachResult = await ctx.browser.cdp.attachToTarget(targetId)
  let sessionId = attachResult["result"]["sessionId"].getStr()
  let tab = cdp.Tab(browser: ctx.browser.cdp, sessionId: sessionId)
  result = page.Page(tab: tab)
  ctx.pages.add(result)

proc close*(ctx: BrowserContext) {.async.} =
  for p in ctx.pages:
    discard await p.tab.sendCommand("Page.close")
  ctx.pages.setLen(0)
  discard await ctx.browser.cdp.sendCommand("Target.disposeBrowserContext",
      %*{"browserContextId": ctx.id})
