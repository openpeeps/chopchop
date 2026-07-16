import std/[asyncdispatch, json, times, strutils, sequtils]
import pkg/cdp as cdp
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
    discard await d.page.tab.sendCommand("Page.handleJavaScriptDialog",
        %*{"accept": true, "promptText": promptText})
  else:
    discard await d.page.tab.sendCommand("Page.handleJavaScriptDialog",
        %*{"accept": true})

proc dismiss*(d: DialogInfo) {.async.} =
  discard await d.page.tab.sendCommand("Page.handleJavaScriptDialog",
      %*{"accept": false})

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

proc matches(pattern: string, url: string): bool =
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
  discard await page.tab.sendCommand("Fetch.enable", %*{
    "patterns": [%*{"urlPattern": "*", "requestStage": "Request"}]
  })
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
  var params = %*{"requestId": r.requestId, "responseCode": status, "body": body}
  if headers.len > 0:
    var h = newJArray()
    for (n, v) in headers:
      h.add(%*{"name": n, "value": v})
    params["responseHeaders"] = h
  discard await r.page.tab.sendCommand("Fetch.fulfillRequest", params)

proc abortRequest*(r: Route) {.async.} =
  await r.page.tab.failRequest(r.requestId, "BlockedByClient")

# ── Device emulation ────────────────────────────────────────────────────────

proc setViewport*(page: Page; width, height: int; deviceScaleFactor: float = 1.0; isMobile: bool = false) {.async.} =
  discard await page.tab.sendCommand("Emulation.setDeviceMetricsOverride", %*{
    "width": width, "height": height,
    "deviceScaleFactor": deviceScaleFactor,
    "mobile": isMobile
  })

proc setUserAgent*(page: Page; userAgent: string) {.async.} =
  discard await page.tab.sendCommand("Emulation.setUserAgentOverride", %*{"userAgent": userAgent})

proc setGeolocation*(page: Page; latitude, longitude, accuracy: float) {.async.} =
  discard await page.tab.sendCommand("Emulation.setGeolocationOverride", %*{
    "latitude": latitude, "longitude": longitude, "accuracy": accuracy
  })

# ── Page-level keyboard ─────────────────────────────────────────────────────

proc press*(page: Page; key: string) {.async.} =
  let (k, c, kc) = getKeyInfo(key)
  await page.tab.dispatchKeyEvent("rawKeyDown", %*{"key": k, "code": c, "windowsVirtualKeyCode": kc})
  await sleepAsync(30)
  if kc > 0 and kc < 128 and key.len == 1:
    await page.tab.dispatchKeyEvent("char", %*{"key": k, "code": c, "text": key})
    await sleepAsync(10)
  await page.tab.dispatchKeyEvent("keyUp", %*{"key": k, "code": c, "windowsVirtualKeyCode": kc})

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

  if navResult.contains("result") and navResult["result"].contains("errorText"):
    let errText = navResult["result"]["errorText"].getStr()
    if errText.len > 0:
      raise newException(cdp.CDPError, "Navigation to " & url & " failed: " & errText)

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
  let resp = await page.tab.sendCommand("Runtime.evaluate",
      %*{"expression": js, "returnByValue": false})
  if resp.contains("result") and resp["result"].contains("result"):
    let inner = resp["result"]["result"]
    if inner.contains("objectId"):
      return inner["objectId"].getStr()
  return ""

proc addInitScript*(page: Page, script: string): Future[string] {.async.} =
  let resp = await page.tab.addScriptToEvaluateOnNewDocument(script)
  if resp.contains("result") and resp["result"].contains("identifier"):
    return resp["result"]["identifier"].getStr()
  return ""

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
  let doc = await page.tab.getDocument()
  let rootNodeId = doc["result"]["root"]["nodeId"].getInt()
  let resp = await page.tab.sendCommand("DOM.getOuterHTML", %*{"nodeId": rootNodeId})
  if resp.contains("result") and resp["result"].contains("outerHTML"):
    return resp["result"]["outerHTML"].getStr()
  return ""

# ── Screenshot ──────────────────────────────────────────────────────────────

proc screenshot*(page: Page; options: ScreenshotOptions = defaultScreenshotOptions()): Future[string] {.async.} =
  var params = %*{"format": options.format}
  if options.quality > 0:
    params["quality"] = %options.quality
  if options.fullPage:
    params["fullPage"] = %(true)
  let resp = await page.tab.captureScreenshot(params)
  if resp.contains("result") and resp["result"].contains("data"):
    return resp["result"]["data"].getStr()
  return ""

# ── DOM querying ────────────────────────────────────────────────────────────

proc querySelector*(page: Page, selector: string): Future[element.ElementHandle] {.async.} =
  let doc = await page.tab.getDocument()
  let rootNodeId = doc["result"]["root"]["nodeId"].getInt()
  let resp = await page.tab.sendCommand("DOM.querySelector", %*{"nodeId": rootNodeId, "selector": selector})
  if resp.contains("result") and resp["result"].contains("nodeId"):
    let nodeId = resp["result"]["nodeId"]
    if nodeId.kind != JNull and nodeId.getInt() != 0:
      return element.ElementHandle(tab: page.tab, selector: selector, index: 0, nodeId: nodeId.getInt())
  return nil

proc querySelectorAll*(page: Page, selector: string): Future[seq[element.ElementHandle]] {.async.} =
  result = @[]
  let doc = await page.tab.getDocument()
  let rootNodeId = doc["result"]["root"]["nodeId"].getInt()
  let resp = await page.tab.sendCommand("DOM.querySelectorAll", %*{"nodeId": rootNodeId, "selector": selector})
  if resp.contains("result") and resp["result"].contains("nodeIds"):
    let nodeIds = resp["result"]["nodeIds"]
    for i in 0 ..< nodeIds.len:
      result.add(element.ElementHandle(tab: page.tab, selector: selector, index: i, nodeId: nodeIds[i].getInt()))

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
  let resp = await page.tab.getCookies()
  if resp.contains("result") and resp["result"].contains("cookies"):
    for c in resp["result"]["cookies"].items:
      result.add(Cookie(
        name: c["name"].getStr(),
        value: c["value"].getStr(),
        domain: if c.contains("domain"): c["domain"].getStr() else: "",
        path: if c.contains("path"): c["path"].getStr() else: "",
        httpOnly: if c.contains("httpOnly"): c["httpOnly"].getBool() else: false,
        secure: if c.contains("secure"): c["secure"].getBool() else: false,
        sameSite: if c.contains("sameSite"): c["sameSite"].getStr() else: ""
      ))

proc setCookie*(page: Page; cookie: Cookie) {.async.} =
  discard await page.tab.sendCommand("Network.setCookie", cookie.toJson())

proc deleteCookie*(page: Page; name: string) {.async.} =
  discard await page.tab.sendCommand("Network.deleteCookies", %*{"name": name})

proc clearCookies*(page: Page) {.async.} =
  discard await page.tab.sendCommand("Network.clearBrowserCookies")

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
