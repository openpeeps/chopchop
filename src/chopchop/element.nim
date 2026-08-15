import std/[asyncdispatch, json, strutils, options]
import devtools as cdp

type
  ElementHandle* = ref object
    tab*: cdp.Tab
    selector*: string
    index*: int
    nodeId*: int

  BoundingBox* = object
    x*, y*, width*, height*: float

# ── Internal helpers ────────────────────────────────────────────────────────

proc selectorToJS(selector: string): string =
  let escaped = selector.replace("`", "\\`").replace("${", "\\${")
  "document.querySelectorAll(`" & escaped & "`)"

proc evalOn*(el: ElementHandle, accessor: string): Future[JsonNode] {.async.} =
  let query = selectorToJS(el.selector) & "[" & $el.index & "]"
  let js = "(() => { try { const el = " & query & "; return el ? (" & accessor & ") : null; } catch(e) { return null; } })()"
  let resp = await el.tab.evaluate(js)
  if resp.contains("result") and resp["result"].contains("result"):
    return resp["result"]["result"]
  return newJNull()

proc escapeJSStr(s: string): string =
  s.replace("\\", "\\\\").replace("'", "\\'").replace("\"", "\\\"")

proc getKeyInfo*(key: string): tuple[key, code: string, keyCode: int] =
  case key
  of "Enter": ("Enter", "Enter", 13)
  of "Tab": ("Tab", "Tab", 9)
  of "Backspace": ("Backspace", "Backspace", 8)
  of "Escape", "Esc": ("Escape", "Escape", 27)
  of "ArrowUp": ("ArrowUp", "ArrowUp", 38)
  of "ArrowDown": ("ArrowDown", "ArrowDown", 40)
  of "ArrowLeft": ("ArrowLeft", "ArrowLeft", 37)
  of "ArrowRight": ("ArrowRight", "ArrowRight", 39)
  of "Delete": ("Delete", "Delete", 46)
  of "Home": ("Home", "Home", 36)
  of "End": ("End", "End", 35)
  of "PageUp": ("PageUp", "PageUp", 33)
  of "PageDown": ("PageDown", "PageDown", 34)
  of "Space": (" ", "Space", 32)
  of "Control", "Ctrl": ("Control", "ControlLeft", 17)
  of "Alt": ("Alt", "AltLeft", 18)
  of "Shift": ("Shift", "ShiftLeft", 16)
  of "Meta": ("Meta", "MetaLeft", 91)
  else:
    if key.len == 1:
      let upper = key.toUpperAscii()
      (key, "Key" & upper, ord(key[0]))
    else:
      (key, key, 0)

# ── Data extraction ─────────────────────────────────────────────────────────

proc innerText*(el: ElementHandle): Future[string] {.async.} =
  let r = await el.evalOn("el.innerText")
  if r.contains("value") and r["value"].kind != JNull:
    return r["value"].getStr()
  return ""

proc innerHTML*(el: ElementHandle): Future[string] {.async.} =
  let r = await el.evalOn("el.innerHTML")
  if r.contains("value") and r["value"].kind != JNull:
    return r["value"].getStr()
  return ""

proc getAttribute*(el: ElementHandle, name: string): Future[string] {.async.} =
  let escaped = name.replace("\\", "\\\\").replace("'", "\\'")
  let r = await el.evalOn("el.getAttribute('" & escaped & "')")
  if r.contains("value") and r["value"].kind != JNull:
    return r["value"].getStr()
  return ""

proc callOn*(el: ElementHandle; fn: string): Future[JsonNode] {.async.} =
  if el.nodeId <= 0:
    return newJNull()
  let objectId = await el.tab.resolveNode(el.nodeId)
  if objectId.len == 0:
    return newJNull()
  let resp = await el.tab.callFunctionOn(cdp.CallFunctionOnParams(
    functionDeclaration: fn,
    objectId: objectId,
    returnByValue: some(true),
    awaitPromise: some(true)
  ))
  if resp.contains("result") and resp["result"].contains("result"):
    return resp["result"]["result"]
  return newJNull()

proc isVisible*(el: ElementHandle): Future[bool] {.async.} =
  let r = await el.callOn("function() { return this.offsetParent !== null; }")
  if r.contains("value") and r["value"].kind != JNull:
    return r["value"].getBool()
  return false

proc getBoundingBox*(el: ElementHandle): Future[BoundingBox] {.async.} =
  discard await el.callOn("function() { this.scrollIntoViewIfNeeded(); }")
  await sleepAsync(50)
  let r = await el.callOn("function() { const r = this.getBoundingClientRect(); return {x: r.x, y: r.y, width: r.width, height: r.height}; }")
  if r.contains("value") and r["value"].kind != JNull:
    let v = r["value"]
    result.x = v["x"].getFloat()
    result.y = v["y"].getFloat()
    result.width = v["width"].getFloat()
    result.height = v["height"].getFloat()

# ── Mouse actions ───────────────────────────────────────────────────────────

proc mouseClickParams(`type`: string; x, y: float): cdp.DispatchMouseEventParams =
  result = cdp.DispatchMouseEventParams(`type`: `type`, x: x, y: y)
  result.button = some("left")
  result.clickCount = some(1)

proc click*(el: ElementHandle) {.async.} =
  discard await el.evalOn("el.scrollIntoViewIfNeeded()")
  await sleepAsync(50)
  let box = await el.getBoundingBox()
  let cx = box.x + box.width / 2
  let cy = box.y + box.height / 2
  await el.tab.dispatchMouseEvent(mouseClickParams("mousePressed", cx, cy))
  await sleepAsync(30)
  await el.tab.dispatchMouseEvent(mouseClickParams("mouseReleased", cx, cy))

proc dblclick*(el: ElementHandle) {.async.} =
  discard await el.evalOn("el.scrollIntoViewIfNeeded()")
  await sleepAsync(50)
  let box = await el.getBoundingBox()
  let cx = box.x + box.width / 2
  let cy = box.y + box.height / 2
  await el.tab.dispatchMouseEvent(mouseClickParams("mousePressed", cx, cy))
  await sleepAsync(30)
  await el.tab.dispatchMouseEvent(mouseClickParams("mouseReleased", cx, cy))
  await sleepAsync(30)
  await el.tab.dispatchMouseEvent(mouseClickParams("mousePressed", cx, cy))
  await sleepAsync(30)
  await el.tab.dispatchMouseEvent(mouseClickParams("mouseReleased", cx, cy))

proc hover*(el: ElementHandle) {.async.} =
  discard await el.evalOn("el.scrollIntoViewIfNeeded()")
  await sleepAsync(50)
  let box = await el.getBoundingBox()
  let cx = box.x + box.width / 2
  let cy = box.y + box.height / 2
  await el.tab.dispatchMouseEvent(cdp.DispatchMouseEventParams(`type`: "mouseMoved", x: cx, y: cy))

proc dragAndDrop*(el: ElementHandle, target: ElementHandle) {.async.} =
  discard await el.evalOn("el.scrollIntoViewIfNeeded()")
  await sleepAsync(50)
  discard await target.evalOn("target.scrollIntoViewIfNeeded()")
  await sleepAsync(50)
  let src = await el.getBoundingBox()
  let tgt = await target.getBoundingBox()
  let srcX = src.x + src.width / 2
  let srcY = src.y + src.height / 2
  let tgtX = tgt.x + tgt.width / 2
  let tgtY = tgt.y + tgt.height / 2
  await el.tab.dispatchMouseEvent(mouseClickParams("mousePressed", srcX, srcY))
  await sleepAsync(50)
  let steps = 10
  for i in 1..steps:
    let t = i.float / steps.float
    let x = srcX + (tgtX - srcX) * t
    let y = srcY + (tgtY - srcY) * t
    await el.tab.dispatchMouseEvent(cdp.DispatchMouseEventParams(`type`: "mouseMoved", x: x, y: y))
    await sleepAsync(10)
  await sleepAsync(50)
  await el.tab.dispatchMouseEvent(mouseClickParams("mouseReleased", tgtX, tgtY))

# ── Keyboard actions ────────────────────────────────────────────────────────

proc typeText*(el: ElementHandle, text: string) {.async.} =
  discard await el.evalOn("el.focus()")
  await sleepAsync(50)
  for ch in text:
    await el.tab.dispatchKeyEvent(cdp.DispatchKeyEventParams(`type`: "char", text: some($ch)))
    await sleepAsync(5)

proc press*(el: ElementHandle, key: string) {.async.} =
  discard await el.evalOn("el.focus()")
  await sleepAsync(50)
  let (k, c, kc) = getKeyInfo(key)
  await el.tab.dispatchKeyEvent(cdp.DispatchKeyEventParams(`type`: "rawKeyDown",
      key: some(k), code: some(c), windowsVirtualKeyCode: some(kc)))
  await sleepAsync(30)
  if kc > 0 and kc < 128 and key.len == 1:
    await el.tab.dispatchKeyEvent(cdp.DispatchKeyEventParams(`type`: "char",
        key: some(k), code: some(c), text: some(key)))
    await sleepAsync(10)
  await el.tab.dispatchKeyEvent(cdp.DispatchKeyEventParams(`type`: "keyUp",
      key: some(k), code: some(c), windowsVirtualKeyCode: some(kc)))

# ── File upload ─────────────────────────────────────────────────────────────

proc setInputFiles*(el: ElementHandle, files: seq[string]) {.async.} =
  if el.nodeId == 0:
    raise newException(ValueError, "ElementHandle has no nodeId; use page.querySelector")
  await el.tab.setFileInputFiles(el.nodeId, files)

# ── Select / option handling ────────────────────────────────────────────────

proc selectByValue*(el: ElementHandle, value: string) {.async.} =
  let v = escapeJSStr(value)
  discard await el.evalOn("(() => { el.value = '" & v & "'; el.dispatchEvent(new Event('change', {bubbles: true})); return true; })()")

proc selectByLabel*(el: ElementHandle, label: string) {.async.} =
  let l = escapeJSStr(label)
  discard await el.evalOn("(() => { const opts = el.options; for(let i=0; i<opts.length; i++) { if(opts[i].text === '" & l & "') { el.selectedIndex = i; el.dispatchEvent(new Event('change', {bubbles: true})); return true; } } return false; })()")

proc selectByIndex*(el: ElementHandle, index: int) {.async.} =
  discard await el.evalOn("(() => { if(el.options.length > " & $index & ") { el.selectedIndex = " & $index & "; el.dispatchEvent(new Event('change', {bubbles: true})); return true; } return false; })()")

proc selectedValues*(el: ElementHandle): Future[seq[string]] {.async.} =
  let r = await el.evalOn("Array.from(el.selectedOptions).map(o => o.value)")
  if r.contains("value") and r["value"].kind != JNull:
    for v in r["value"].items:
      result.add(v.getStr())
