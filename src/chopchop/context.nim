import std/[asyncdispatch, options]
import devtools as cdp
import types, page, browser

type
  BrowserContext* = ref object
    browser*: browser.Browser
    id*: string
    pages*: seq[page.Page]

proc newContext*(b: browser.Browser; options: BrowserContextOptions = defaultBrowserContextOptions()): Future[BrowserContext] {.async.} =
  let ctxId = await b.cdp.createBrowserContext()
  result = BrowserContext(browser: b, id: ctxId)

proc newPage*(ctx: BrowserContext; options: NavigationOptions = defaultNavigationOptions()): Future[page.Page] {.async.} =
  let targetId = await ctx.browser.cdp.createTarget(
      cdp.CreateTargetParams(url: "about:blank", browserContextId: some(ctx.id)))
  let sessionId = await ctx.browser.cdp.attachToTarget(targetId)
  let tab = cdp.Tab(browser: ctx.browser.cdp, sessionId: sessionId)
  result = page.Page(tab: tab)
  ctx.pages.add(result)

proc close*(ctx: BrowserContext) {.async.} =
  for p in ctx.pages:
    await p.tab.closePage()
  ctx.pages.setLen(0)
  await ctx.browser.cdp.disposeBrowserContext(ctx.id)
