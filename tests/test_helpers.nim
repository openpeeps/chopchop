import std/[unittest, options, json]
import ../src/chopchop
import ../src/chopchop/devtools as cdp
import pkg/openparser/json

suite "parseEndpoint":
  test "parses host, port and path":
    let ep = cdp.parseEndpoint("ws://127.0.0.1:9222/devtools/browser/abc")
    check ep.address == "127.0.0.1"
    check ep.port == 9222
    check ep.path == "/devtools/browser/abc"

  test "parses localhost":
    let ep = cdp.parseEndpoint("ws://localhost:1234/devtools/page/xyz")
    check ep.address == "localhost"
    check ep.port == 1234
    check ep.path == "/devtools/page/xyz"

  test "handles missing scheme":
    let ep = cdp.parseEndpoint("127.0.0.1:9222/devtools/browser/abc")
    check ep.address == "127.0.0.1"
    check ep.port == 9222
    check ep.path == "/devtools/browser/abc"

  test "handles missing path":
    let ep = cdp.parseEndpoint("ws://127.0.0.1:9222")
    check ep.address == "127.0.0.1"
    check ep.port == 9222
    check ep.path == "/"

suite "stripNulls":
  test "drops null object members":
    let node = parseJson("""{"a": null, "b": 1, "c": {"x": null, "y": "z"}}""")
    let res = cdp.stripNulls(node)
    check res == parseJson("""{"b": 1, "c": {"y": "z"}}""")

  test "drops null array elements":
    let node = parseJson("""[null, 1, {"a": null}, [null, 2]]""")
    let res = cdp.stripNulls(node)
    check res == parseJson("""[1, {}, [2]]""")

  test "keeps non-null values and leaves scalars untouched":
    check cdp.stripNulls(parseJson(""""text"""")) == parseJson(""""text"""")
    check cdp.stripNulls(parseJson("42")) == parseJson("42")
    check cdp.stripNulls(parseJson("null")) == parseJson("null")

suite "typed CDP params serialize without nulls":
  test "CaptureScreenshotParams keeps only set fields":
    let wire = cdp.stripNulls(toJsonNode(cdp.CaptureScreenshotParams(format: "png")))
    check wire == parseJson("""{"format": "png"}""")

  test "CaptureScreenshotParams with quality and fullPage":
    let wire = cdp.stripNulls(toJsonNode(cdp.CaptureScreenshotParams(
        format: "jpeg", quality: some(80), fullPage: some(true))))
    check wire == parseJson("""{"format": "jpeg", "quality": 80, "fullPage": true}""")

  test "DispatchKeyEventParams omits unset optionals":
    let wire = cdp.stripNulls(toJsonNode(cdp.DispatchKeyEventParams(
        `type`: "char", text: some("a"))))
    check wire == parseJson("""{"type": "char", "text": "a"}""")
    check not wire.contains("key")
    check not wire.contains("windowsVirtualKeyCode")

  test "DispatchMouseEventParams with button":
    let wire = cdp.stripNulls(toJsonNode(cdp.DispatchMouseEventParams(
        `type`: "mousePressed", x: 10.5, y: 20.0, button: some("left"),
        clickCount: some(1))))
    check wire == parseJson("""{"type": "mousePressed", "x": 10.5, "y": 20.0,
        "button": "left", "clickCount": 1}""")

  test "SetDeviceMetricsOverrideParams":
    let wire = cdp.stripNulls(toJsonNode(cdp.SetDeviceMetricsOverrideParams(
        width: 375, height: 812, deviceScaleFactor: 3.0, mobile: true)))
    check wire == parseJson("""{"width": 375, "height": 812,
        "deviceScaleFactor": 3.0, "mobile": true}""")

suite "getKeyInfo":
  test "named keys":
    check getKeyInfo("Enter") == ("Enter", "Enter", 13)
    check getKeyInfo("Tab") == ("Tab", "Tab", 9)
    check getKeyInfo("Backspace") == ("Backspace", "Backspace", 8)
    check getKeyInfo("ArrowUp") == ("ArrowUp", "ArrowUp", 38)
    check getKeyInfo("Space") == (" ", "Space", 32)

  test "single printable characters":
    let (k, code, kc) = getKeyInfo("a")
    check k == "a"
    check code == "KeyA"
    check kc == ord('a')
    let (k2, code2, kc2) = getKeyInfo("A")
    check k2 == "A"
    check code2 == "KeyA"

  test "modifier aliases":
    check getKeyInfo("Ctrl") == ("Control", "ControlLeft", 17)
    check getKeyInfo("Esc") == ("Escape", "Escape", 27)
    check getKeyInfo("Meta") == ("Meta", "MetaLeft", 91)

suite "route pattern matching":
  test "wildcard matches everything":
    check matches("*", "https://example.com/foo")
    check matches("", "https://example.com/foo")

  test "prefix without wildcard":
    check matches("https://example.com", "https://example.com/page")
    check not matches("https://example.org", "https://example.com/page")

  test "wildcard in middle":
    check matches("https://*.example.com", "https://api.example.com")
    check not matches("https://*.example.com", "https://example.org")

  test "multiple wildcards":
    check matches("https://*/*.png", "https://cdn.example.com/img/icon.png")
    check not matches("https://*/*.png", "https://cdn.example.com/img/icon.jpg")
