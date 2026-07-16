import std/[asyncdispatch, times, strutils]
import element, page

type
  LocatorTimeoutError* = object of CatchableError

# ── Resolve ──────────────────────────────────────────────────────────────────

proc resolve*(loc: Locator): Future[seq[ElementHandle]] {.async.} =
  if loc.filterText.len == 0:
    result = await loc.page.querySelectorAll(loc.selector)
  else:
    result = @[]
    let candidates = await loc.page.querySelectorAll(loc.selector)
    for el in candidates:
      let text = await el.innerText()
      if loc.exact:
        if text == loc.filterText:
          result.add(el)
      else:
        if text.contains(loc.filterText):
          result.add(el)

  if loc.nthOnly == -2 and result.len > 0:
    result = @[result[^1]]
  elif loc.nthOnly >= 0 and loc.nthOnly < result.len:
    result = @[result[loc.nthOnly]]

# ── Actionability checks ─────────────────────────────────────────────────────

proc isClickable(el: ElementHandle): Future[tuple[ok: bool; reason: string]] {.async.} =
  try:
    let visible = await el.isVisible()
    let box = await el.getBoundingBox()
    if not visible:
      return (false, "not visible")
    if box.width <= 0 or box.height <= 0:
      return (false, "zero box (" & $box.width & "x" & $box.height & ")")
    return (true, "")
  except CatchableError as e:
    return (false, "exception: " & e.msg)

# ── Auto-wait ────────────────────────────────────────────────────────────────

proc waitForActionable*(loc: Locator): Future[ElementHandle] {.async.} =
  if loc.selector.len == 0 and loc.filterText.len == 0:
    raise newException(LocatorTimeoutError, "Locator has no selector")
  let startTime = epochTime()
  while true:
    let elapsed = (epochTime() - startTime) * 1000
    if elapsed >= loc.timeout.float:
      raise newException(LocatorTimeoutError,
        "Timed out after " & $loc.timeout & "ms waiting for \"" & loc.selector & "\"")
    let els = await loc.resolve()
    if els.len == 0:
      await sleepAsync(100)
      continue
    let el = els[0]
    let (ok, reason) = await el.isClickable()
    if ok:
      return el
    await sleepAsync(100)

proc waitForCount*(loc: Locator; count: int): Future[bool] {.async.} =
  let startTime = epochTime()
  while true:
    let elapsed = (epochTime() - startTime) * 1000
    if elapsed >= loc.timeout.float:
      return false
    let els = await loc.resolve()
    if els.len >= count:
      return true
    await sleepAsync(100)

# ── Actions ──────────────────────────────────────────────────────────────────

proc click*(loc: Locator) {.async.} =
  let el = await loc.waitForActionable()
  await el.click()

proc dblclick*(loc: Locator) {.async.} =
  let el = await loc.waitForActionable()
  await el.dblclick()

proc hover*(loc: Locator) {.async.} =
  let el = await loc.waitForActionable()
  await el.hover()

proc typeText*(loc: Locator; text: string) {.async.} =
  let el = await loc.waitForActionable()
  await el.typeText(text)

proc press*(loc: Locator; key: string) {.async.} =
  let el = await loc.waitForActionable()
  await el.press(key)

proc fill*(loc: Locator; text: string) {.async.} =
  let el = await loc.waitForActionable()
  discard await el.evalOn("el.focus()")
  await sleepAsync(50)
  discard await el.evalOn("el.value = ''")
  await sleepAsync(30)
  await el.typeText(text)

proc selectOption*(loc: Locator; value: string) {.async.} =
  let el = await loc.waitForActionable()
  await el.selectByValue(value)

proc selectOptionByLabel*(loc: Locator; label: string) {.async.} =
  let el = await loc.waitForActionable()
  await el.selectByLabel(label)

proc selectOptionByIndex*(loc: Locator; index: int) {.async.} =
  let el = await loc.waitForActionable()
  await el.selectByIndex(index)

proc setInputFiles*(loc: Locator; files: seq[string]) {.async.} =
  let el = await loc.waitForActionable()
  await el.setInputFiles(files)

# ── Extraction ───────────────────────────────────────────────────────────────

proc innerText*(loc: Locator): Future[string] {.async.} =
  let el = await loc.waitForActionable()
  return await el.innerText()

proc innerHTML*(loc: Locator): Future[string] {.async.} =
  let el = await loc.waitForActionable()
  return await el.innerHTML()

proc getAttribute*(loc: Locator; name: string): Future[string] {.async.} =
  let el = await loc.waitForActionable()
  return await el.getAttribute(name)

proc isVisible*(loc: Locator): Future[bool] {.async.} =
  let els = await loc.resolve()
  if els.len == 0: return false
  return await els[0].isVisible()

proc count*(loc: Locator): Future[int] {.async.} =
  let els = await loc.resolve()
  return els.len
