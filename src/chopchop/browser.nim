import std/[asyncdispatch]
import devtools as cdp
import types, page

type
  Browser* = ref object
    cdp*: cdp.Browser
    pages: seq[page.Page]

proc launchBrowser*(options: LaunchOptions = defaultLaunchOptions()): Future[Browser] {.async.} =
  let headlessMode =
    if options.headless: cdp.HeadlessMode.On
    else: cdp.HeadlessMode.Off
  let cdpBrowser = await cdp.launchBrowser(
    userDataDir = options.userDataDir,
    portNo = options.portNo,
    headlessMode = headlessMode,
    chromeArguments = options.chromeArgs
  )
  result = Browser(cdp: cdpBrowser)

proc close*(browser: Browser) {.async.} =
  await browser.cdp.close()

proc newPage*(browser: Browser): Future[page.Page] {.async.} =
  let tab = await browser.cdp.newTab()
  result = page.Page(tab: tab)
  browser.pages.add(result)
