import std/[asyncdispatch, json, times, strutils, sequtils, options]
import devtools as cdp
import types, element

# ── Types ───────────────────────────────────────────────────────────────────

type
  Page* = ref object
    tab*: cdp.Tab
    dialogHandler*: proc(d: DialogInfo): Future[void]
    consoleHandler*: proc(msg: ConsoleMessage): Future[void]
    routes*: seq[RouteRule]

  DialogInfo* = ref object
    page*: Page
    message*: string
    dialogType*: string
    defaultPrompt*: string

  ConsoleMessage* = ref object
    text*: string
    level*: string
    timestamp*: float

  ConsoleHandler* = proc(msg: ConsoleMessage): Future[void]

  RouteRule* = object
    pattern*: string
    handler*: RouteHandler

  RouteHandler* = proc(r: Route): Future[void]

  Route* = ref object
    page: Page
    requestId*: string
    url*: string
    httpMethod*: string
    headers*: JsonNode
    postData*: string

  Locator* = ref object
    page*: Page
    selector*: string
    nthOnly*: int           # -1 = use first; 0+ = specific index
    timeout*: int           # auto-wait timeout in ms
    filterText*: string     # text content filter (empty = none)
    exact*: bool            # exact text match

# ── Locator creation ─────────────────────────────────────────────────────────

proc locator*(page: Page; selector: string;
              timeout: int = 30000): Locator =
  Locator(page: page, selector: selector, nthOnly: -1,
          timeout: timeout)

proc getByText*(page: Page; text: string;
                exact: bool = false;
                timeout: int = 30000): Locator =
  Locator(page: page, selector: "", filterText: text,
          exact: exact, nthOnly: -1, timeout: timeout)

proc locator*(loc: Locator; selector: string): Locator =
  let combined =
    if loc.selector.len > 0:
      loc.selector & " " & selector
    else:
      selector
  Locator(page: loc.page, selector: combined,
          filterText: loc.filterText, exact: loc.exact,
          nthOnly: -1, timeout: loc.timeout)

proc filter*(loc: Locator; hasText: string = ""): Locator =
  Locator(page: loc.page, selector: loc.selector,
          filterText: hasText, exact: false,
          nthOnly: -1, timeout: loc.timeout)

proc first*(loc: Locator): Locator =
  Locator(page: loc.page, selector: loc.selector,
          filterText: loc.filterText, exact: loc.exact,
          nthOnly: 0, timeout: loc.timeout)

proc last*(loc: Locator): Locator =
  Locator(page: loc.page, selector: loc.selector,
          filterText: loc.filterText, exact: loc.exact,
          nthOnly: -2, timeout: loc.timeout)
  # -2 is a sentinel meaning "last"

proc nth*(loc: Locator; index: int): Locator =
  Locator(page: loc.page, selector: loc.selector,
          filterText: loc.filterText, exact: loc.exact,
          nthOnly: index, timeout: loc.timeout)

# ── Dialog handling ─────────────────────────────────────────────────────────

proc accept*(d: DialogInfo; promptText: string = "") {.async.} =
  if promptText.len > 0:
    await d.page.tab.handleJavaScriptDialog(
        cdp.HandleJavaScriptDialogParams(accept: true, promptText: some(promptText)))
  else:
    await d.page.tab.handleJavaScriptDialog(true)

proc dismiss*(d: DialogInfo) {.async.} =
  await d.page.tab.handleJavaScriptDialog(false)

proc setupDialogHandler(page: Page) {.async.} =
  await page.tab.enablePageDomain()
  page.tab.browser.addSessionEventCallback(page.tab.sessionId,
      $cdp.Page.javascriptDialogOpening,
      proc(jsn: JsonNode) {.async.} =
        let params = jsn["params"]
        let d = DialogInfo(
          page: page,
          message: params["message"].getStr(),
          dialogType: params["type"].getStr(),
          defaultPrompt: if params.contains("defaultPrompt"): params["defaultPrompt"].getStr() else: ""
        )
        if page.dialogHandler != nil:
          await page.dialogHandler(d)
        else:
          await d.accept()
  )

proc onDialog*(page: Page; handler: proc(d: DialogInfo): Future[void]) {.async.} =
  page.dialogHandler = handler
  await page.setupDialogHandler()

# ── Console capture ─────────────────────────────────────────────────────────

proc setupConsoleCapture(page: Page) {.async.} =
  await page.tab.enableRuntimeDomain()
  page.tab.browser.addSessionEventCallback(page.tab.sessionId,
      $cdp.Runtime.consoleAPICalled,
      proc(jsn: JsonNode) {.async.} =
        let params = jsn["params"]
        var text = ""
        if params.contains("args"):
          for arg in params["args"].items:
            if arg.contains("value") and arg["value"].kind != JNull:
              if text.len > 0: text.add(" ")
              text.add(arg["value"].getStr())
        let msg = ConsoleMessage(
          text: text,
          level: if params.contains("type"): params["type"].getStr() else: "log",
          timestamp: if params.contains("timestamp"): params["timestamp"].getFloat() else: 0.0
        )
        if page.consoleHandler != nil:
          await page.consoleHandler(msg)
  )

proc onConsole*(page: Page; handler: proc(msg: ConsoleMessage): Future[void]) {.async.} =
  page.consoleHandler = handler
  await page.setupConsoleCapture()

# ── Network interception ────────────────────────────────────────────────────

proc matches*(pattern: string, url: string): bool =
  ## Matches a URL against a glob-style route `pattern` (`*` wildcards or a
  ## plain prefix). Internal helper; exported for testing.
  if pattern == "*" or pattern == "":
    return true
  if pattern.contains("*"):
    let parts = pattern.split("*")
    var pos = 0
    for part in parts:
      if part.len == 0: continue
      let idx = url.find(part, pos)
      if idx < 0: return false
      pos = idx + part.len
    return true
  url.startsWith(pattern)

proc setupNetworkInterception(page: Page) {.async.} =
  await page.tab.enableFetchDomain(cdp.FetchEnableParams(patterns: @[
    cdp.FetchRequestPattern(urlPattern: "*", requestStage: some("Request"))]))
  page.tab.browser.addSessionEventCallback(page.tab.sessionId,
      "Fetch.requestPaused",
      proc(jsn: JsonNode) {.async.} =
        let params = jsn["params"]
        let reqUrl = params["request"]["url"].getStr()
        for rule in page.routes:
          if matches(rule.pattern, reqUrl):
            let r = Route(
              page: page,
              requestId: params["requestId"].getStr(),
              url: reqUrl,
              httpMethod: params["request"]["method"].getStr(),
              headers: params["request"]["headers"],
              postData: if params["request"].contains("postData"): params["request"]["postData"].getStr() else: ""
            )
            await rule.handler(r)
            return
        # No matching route: continue
        await page.tab.continueRequest(params["requestId"].getStr())
  )

proc route*(page: Page; pattern: string; handler: RouteHandler) {.async.} =
  if page.routes.len == 0:
    await page.setupNetworkInterception()
  page.routes.add(RouteRule(pattern: pattern, handler: handler))

proc unroute*(page: Page; pattern: string) =
  page.routes.keepIf(proc(r: RouteRule): bool = r.pattern != pattern)

proc continueRequest*(r: Route) {.async.} =
  await r.page.tab.continueRequest(r.requestId)

proc fulfillRequest*(r: Route; status: int = 200; body: string = "";
                     headers: seq[tuple[name, value: string]] = @[]) {.async.} =
  var params = cdp.FulfillRequestParams(requestId: r.requestId, responseCode: status)
  if body.len > 0:
    params.body = some(body)
  if headers.len > 0:
    var hs: seq[cdp.HeaderEntry]
    for (n, v) in headers:
      hs.add(cdp.HeaderEntry(name: n, value: v))
    params.responseHeaders = some(hs)
  await r.page.tab.fulfillRequest(params)

proc abortRequest*(r: Route) {.async.} =
  await r.page.tab.failRequest(r.requestId, "BlockedByClient")

# ── Device emulation ────────────────────────────────────────────────────────

proc setViewport*(page: Page; width, height: int; deviceScaleFactor: float = 1.0; isMobile: bool = false) {.async.} =
  await page.tab.setDeviceMetricsOverride(width, height, deviceScaleFactor, isMobile)

proc setUserAgent*(page: Page; userAgent: string) {.async.} =
  await page.tab.setUserAgentOverride(userAgent)

proc setGeolocation*(page: Page; latitude, longitude, accuracy: float) {.async.} =
  await page.tab.setGeolocationOverride(latitude, longitude, accuracy)

# ── Page-level keyboard ─────────────────────────────────────────────────────

proc press*(page: Page; key: string) {.async.} =
  let (k, c, kc) = getKeyInfo(key)
  await page.tab.dispatchKeyEvent(cdp.DispatchKeyEventParams(`type`: "rawKeyDown",
      key: some(k), code: some(c), windowsVirtualKeyCode: some(kc)))
  await sleepAsync(30)
  if kc > 0 and kc < 128 and key.len == 1:
    await page.tab.dispatchKeyEvent(cdp.DispatchKeyEventParams(`type`: "char",
        key: some(k), code: some(c), text: some(key)))
    await sleepAsync(10)
  await page.tab.dispatchKeyEvent(cdp.DispatchKeyEventParams(`type`: "keyUp",
      key: some(k), code: some(c), windowsVirtualKeyCode: some(kc)))

# ── Navigation ──────────────────────────────────────────────────────────────

proc enableNetworkIfNeeded(page: Page): Future[void] {.async.} =
  await page.tab.enableNetworkDomain()

proc waitForNetworkIdle(page: Page; idleTime = 500, timeout = 30000): Future[void] {.async.} =
  let inflight = new(int)
  inflight[] = 0
  await page.enableNetworkIfNeeded()

  page.tab.browser.addSessionEventCallback(page.tab.sessionId,
      "Network.requestWillBeSent",
      proc(jsn: JsonNode) {.async.} = inflight[] += 1)
  page.tab.browser.addSessionEventCallback(page.tab.sessionId,
      "Network.loadingFinished",
      proc(jsn: JsonNode) {.async.} =
        if inflight[] > 0: inflight[] -= 1)
  page.tab.browser.addSessionEventCallback(page.tab.sessionId,
      "Network.loadingFailed",
      proc(jsn: JsonNode) {.async.} =
        if inflight[] > 0: inflight[] -= 1)

  let deadline = epochTime() + timeout.float / 1000.0
  while epochTime() < deadline:
    if inflight[] <= 0:
      return
    await sleepAsync(100)
  raise newException(ValueError, "Timed out waiting for network idle")

proc goto*(page: Page, url: string; options: NavigationOptions = defaultNavigationOptions()): Future[void] {.async.} =
  await page.tab.enablePageDomain()

  let waitFuture =
    if options.waitUntil != NavigationWaitUntil.NetworkIdle:
      case options.waitUntil
      of NavigationWaitUntil.Load:
        page.tab.browser.waitForSessionEvent(page.tab.sessionId, $cdp.Page.loadEventFired)
      of NavigationWaitUntil.DOMContentLoaded:
        page.tab.browser.waitForSessionEvent(page.tab.sessionId, $cdp.Page.domContentEventFired)
      else:
        nil
    else:
      nil

  let navResult = await page.tab.navigate(url)

  if options.waitUntil == NavigationWaitUntil.NetworkIdle:
    await page.waitForNetworkIdle(timeout = options.timeout)
  elif waitFuture != nil:
    discard await waitFuture.withTimeout(options.timeout)

  if navResult.errorText.isSome and navResult.errorText.get().len > 0:
    raise newException(cdp.CDPError, "Navigation to " & url & " failed: " &
        navResult.errorText.get())

proc waitForNavigation*(page: Page; options: WaitForNavigationOptions = defaultWaitForNavigationOptions()): Future[void] {.async.} =
  await page.tab.enablePageDomain()
  if options.waitUntil == NavigationWaitUntil.NetworkIdle:
    await page.waitForNetworkIdle(timeout = options.timeout)
  else:
    let waitFuture =
      case options.waitUntil
      of NavigationWaitUntil.Load:
        page.tab.browser.waitForSessionEvent(page.tab.sessionId, $cdp.Page.loadEventFired)
      of NavigationWaitUntil.DOMContentLoaded:
        page.tab.browser.waitForSessionEvent(page.tab.sessionId, $cdp.Page.domContentEventFired)
      else:
        nil
    if waitFuture != nil:
      discard await waitFuture.withTimeout(options.timeout)

# ── JS Evaluation ───────────────────────────────────────────────────────────

proc evaluate*(page: Page, js: string): Future[JsonNode] {.async.} =
  let resp = await page.tab.evaluate(js)
  if resp.contains("result") and resp["result"].contains("result"):
    return resp["result"]["result"]
  return newJNull()

proc evaluateHandle*(page: Page, js: string): Future[string] {.async.} =
  let resp = await page.tab.evaluate(cdp.EvaluateParams(expression: js))
  if resp.contains("result") and resp["result"].contains("result"):
    let inner = resp["result"]["result"]
    if inner.contains("objectId"):
      return inner["objectId"].getStr()
  return ""

proc addInitScript*(page: Page, script: string): Future[string] {.async.} =
  result = await page.tab.addScriptToEvaluateOnNewDocument(script)

# ── Simple data extraction ──────────────────────────────────────────────────

proc title*(page: Page): Future[string] {.async.} =
  let r = await page.evaluate("document.title")
  if r.contains("value") and r["value"].kind != JNull:
    return r["value"].getStr()
  return ""

proc url*(page: Page): Future[string] {.async.} =
  let r = await page.evaluate("document.location.href")
  if r.contains("value") and r["value"].kind != JNull:
    return r["value"].getStr()
  return ""

proc content*(page: Page): Future[string] {.async.} =
  let rootNodeId = await page.tab.getDocument()
  result = await page.tab.getOuterHTML(rootNodeId)

# ── Screenshot ──────────────────────────────────────────────────────────────

proc screenshot*(page: Page; options: ScreenshotOptions = defaultScreenshotOptions()): Future[string] {.async.} =
  var params = cdp.CaptureScreenshotParams(format: options.format)
  if options.quality > 0:
    params.quality = some(options.quality)
  if options.fullPage:
    params.fullPage = some(true)
  result = await page.tab.captureScreenshot(params)

# ── DOM querying ────────────────────────────────────────────────────────────

proc querySelector*(page: Page, selector: string): Future[element.ElementHandle] {.async.} =
  let rootNodeId = await page.tab.getDocument()
  let nodeId = await page.tab.querySelector(rootNodeId, selector)
  if nodeId != 0:
    return element.ElementHandle(tab: page.tab, selector: selector, index: 0, nodeId: nodeId)
  return nil

proc querySelectorAll*(page: Page, selector: string): Future[seq[element.ElementHandle]] {.async.} =
  result = @[]
  let rootNodeId = await page.tab.getDocument()
  let nodeIds = await page.tab.querySelectorAll(rootNodeId, selector)
  for i, nodeId in nodeIds:
    result.add(element.ElementHandle(tab: page.tab, selector: selector, index: i, nodeId: nodeId))

# ── Waiting ─────────────────────────────────────────────────────────────────

proc waitForSelector*(page: Page, selector: string; options: WaitForSelectorOptions = defaultWaitForSelectorOptions()): Future[element.ElementHandle] {.async.} =
  let deadline = epochTime() + options.timeout.float / 1000.0
  while epochTime() < deadline:
    let el = await page.querySelector(selector)
    if el != nil:
      return el
    await sleepAsync(100)
  raise newException(ValueError, "Timed out waiting for selector: " & selector)

# ── Cookies ─────────────────────────────────────────────────────────────────

proc cookies*(page: Page): Future[seq[Cookie]] {.async.} =
  result = @[]
  let cs = await page.tab.getCookies()
  for c in cs:
    result.add(Cookie(
      name: c.name,
      value: c.value,
      domain: c.domain,
      path: c.path,
      httpOnly: c.httpOnly,
      secure: c.secure,
      sameSite: c.sameSite
    ))

proc setCookie*(page: Page; cookie: Cookie) {.async.} =
  var params = cdp.SetCookieParams(name: cookie.name, value: cookie.value)
  if cookie.domain.len > 0: params.domain = some(cookie.domain)
  if cookie.path.len > 0: params.path = some(cookie.path)
  if cookie.httpOnly: params.httpOnly = some(true)
  if cookie.secure: params.secure = some(true)
  if cookie.sameSite.len > 0: params.sameSite = some(cookie.sameSite)
  if cookie.domain.len == 0:
    params.url = some(await page.url())
  await page.tab.setCookie(params)

proc deleteCookie*(page: Page; name: string) {.async.} =
  var params = cdp.DeleteCookiesParams(name: name)
  params.url = some(await page.url())
  await page.tab.deleteCookies(params)

proc clearCookies*(page: Page) {.async.} =
  await page.tab.clearBrowserCookies()

# ── Storage ─────────────────────────────────────────────────────────────────

proc localStorage*(page: Page, key: string): Future[string] {.async.} =
  let k = key.replace("\\", "\\\\").replace("'", "\\'")
  let r = await page.evaluate("localStorage.getItem('" & k & "')")
  if r.contains("value") and r["value"].kind != JNull:
    return r["value"].getStr()
  return ""

proc setLocalStorage*(page: Page, key, value: string) {.async.} =
  let k = key.replace("\\", "\\\\").replace("'", "\\'")
  let v = value.replace("\\", "\\\\").replace("'", "\\'")
  discard await page.evaluate("localStorage.setItem('" & k & "','" & v & "')")

proc sessionStorage*(page: Page, key: string): Future[string] {.async.} =
  let k = key.replace("\\", "\\\\").replace("'", "\\'")
  let r = await page.evaluate("sessionStorage.getItem('" & k & "')")
  if r.contains("value") and r["value"].kind != JNull:
    return r["value"].getStr()
  return ""

proc setSessionStorage*(page: Page, key, value: string) {.async.} =
  let k = key.replace("\\", "\\\\").replace("'", "\\'")
  let v = value.replace("\\", "\\\\").replace("'", "\\'")
  discard await page.evaluate("sessionStorage.setItem('" & k & "','" & v & "')")
