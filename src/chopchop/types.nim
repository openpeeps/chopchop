import std/[json]

type
  LaunchOptions* = object
    headless*: bool
    userDataDir*: string
    chromeArgs*: seq[string]
    portNo*: int

  NavigationWaitUntil* {.pure.} = enum
    Load, DOMContentLoaded, NetworkIdle

  NavigationOptions* = object
    waitUntil*: NavigationWaitUntil
    timeout*: int

  ScreenshotOptions* = object
    format*: string
    quality*: int
    fullPage*: bool

  WaitForSelectorOptions* = object
    timeout*: int

  WaitForNavigationOptions* = object
    waitUntil*: NavigationWaitUntil
    timeout*: int

  BrowserContextOptions* = object
    userAgent*: string
    viewport*: ViewportOptions

  ViewportOptions* = object
    width*: int
    height*: int
    deviceScaleFactor*: float64
    isMobile*: bool

  Cookie* = object
    name*: string
    value*: string
    domain*: string
    path*: string
    httpOnly*: bool
    secure*: bool
    sameSite*: string

  SelectOptionValue* = object
    value*: string
    label*: string
    index*: int

proc defaultLaunchOptions*: LaunchOptions =
  LaunchOptions(headless: true, portNo: 0)

proc defaultNavigationOptions*: NavigationOptions =
  NavigationOptions(waitUntil: NavigationWaitUntil.Load, timeout: 30000)

proc defaultScreenshotOptions*: ScreenshotOptions =
  ScreenshotOptions(format: "png")

proc defaultWaitForSelectorOptions*: WaitForSelectorOptions =
  WaitForSelectorOptions(timeout: 30000)

proc defaultWaitForNavigationOptions*: WaitForNavigationOptions =
  WaitForNavigationOptions(waitUntil: NavigationWaitUntil.Load, timeout: 30000)

proc defaultBrowserContextOptions*: BrowserContextOptions =
  BrowserContextOptions(viewport: ViewportOptions(width: 1280, height: 720))

proc toJson*(cookie: Cookie): JsonNode =
  result = %*{
    "name": cookie.name,
    "value": cookie.value
  }
  if cookie.domain.len > 0: result["domain"] = %cookie.domain
  if cookie.path.len > 0: result["path"] = %cookie.path
  if cookie.httpOnly: result["httpOnly"] = %(true)
  if cookie.secure: result["secure"] = %(true)
  if cookie.sameSite.len > 0: result["sameSite"] = %cookie.sameSite
