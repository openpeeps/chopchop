## This module contains procedures for the `Browser` object type.
## The `Browser` object is used to interact with a Chrome browser instance,
## create new tabs, register and listen for CDP events, etc.
##
## powpow runs its own event loop; chopchop uses asyncdispatch. The two are
## bridged cooperatively on a single thread: a periodic asyncdispatch timer
## drives `loop.poll(0)`, which advances powpow's DNS/TCP/WebSocket state and
## dispatches inbound frames to the CDP response/event tables. Because
## everything runs on the main thread, no locks or cross-thread marshaling
## are needed.

import std/[json, asyncdispatch, tables, os, tempfiles, osproc, strutils]
import pkg/powpow
import pkg/openparser/json
import base, chrome, ../domains/[target, browser_domain]

{.experimental: "codeReordering".}

proc parseEndpoint*(endpoint: string): tuple[address: string, port: int, path: string] =
  ## Parses a CDP websocket endpoint (`ws://host:port/path`) into its parts.
  ## Internal helper; exported for testing.
  var url = endpoint
  if url.startsWith("ws://"):
    url = url[5 .. ^1]
  let slash = url.find('/')
  let authority =
    if slash >= 0: url[0 ..< slash]
    else: url
  result.path =
    if slash >= 0: url[slash .. ^1]
    else: "/"
  let colon = authority.rfind(':')
  if colon < 0:
    result.address = authority
    result.port = 80
  else:
    result.address = authority[0 ..< colon]
    result.port = parseInt(authority[colon + 1 .. ^1])

proc handleWsPacket(browser: Browser, data: openArray[byte]) =
  ## Dispatches a single inbound WebSocket message: completes the pending
  ## response future for `id` packets, or fires session/global event
  ## callbacks for `method` packets.
  let packet = cast[string](@data)
  let jsn = fromJson(packet)
  if jsn.hasKey("id"): # CDP response
    let id = jsn["id"].getInt()
    if browser.responseTable.hasKey(id):
      browser.responseTable[id].complete(jsn)
      browser.responseTable.del(id)
    else:
      raise newException(CDPError,
          "received response for unknown request id " & $id & ": " & packet)
  elif jsn.hasKey("method"): # CDP event
    let mthd = jsn["method"].getStr()
    if jsn.hasKey("sessionId"): # CDP Session event
      let sessionId = jsn["sessionId"].getStr()
      if browser.sessionEventTable.hasKey(sessionId):
        if browser.sessionEventTable[sessionId].hasKey(mthd):
          asyncCheck browser.sessionEventTable[sessionId][mthd](jsn)
    else: # CDP Global event
      if browser.globalEventTable.hasKey(mthd):
        asyncCheck browser.globalEventTable[mthd](jsn)
  else: # CDP error of some kind
    raise newException(CDPError,
        "JSON from CDP packet does not contain 'id' or 'method':\n" & packet)

proc startPollLoop(browser: Browser) =
  ## Drives powpow's event loop from asyncdispatch by polling it
  ## non-blockingly on a ~1ms timer.
  browser.polling = true
  proc pollDriver() {.async.} =
    try:
      while browser.polling:
        browser.loop.poll(0)
        await sleepAsync(1)
    except Exception as e:
      stderr.writeLine("[pollDriver] error: " & e.msg & "\n" & e.getStackTrace())
  asyncCheck pollDriver()

proc launchBrowser*(userDataDir = "";
                    portNo = 0; headlessMode = HeadlessMode.On;
                    chromeArguments: seq[string] = @[]): Future[Browser] {.async.} =
  ## Launches a new Chrome browser instance and returns a `Browser` object.
  ##
  ## `userDataDir` parameter can be used to specify a directory where the
  ## browser's user data will be stored. If an empty string is passed, a
  ## temporary directory will be created and used.
  ##
  ## `portNo` parameter can be used to specify a port number for the browser
  ## to listen on. If `portNo` is 0, chrome will choose a random port.
  ##
  ## `headlessMode` parameter can be used to specify whether the browser should
  ## be launched in headless mode or not. `HeadlessMode.On` (the default) will
  ## launch the new version of Chrome headless mode (for Chrome >= v112).
  ##
  ## `chromeArguments` parameter can be used to pass additional arguments to
  ## the Chrome browser instance.
  new result
  if userDataDir == "":
    var tmpDir: string
    try:
      tmpDir = createTempDir("cdp_", "_tmpdir")
    except OSError as e:
      echo "Error creating temp dir: " & e.msg
      raise e
    result.userDataDir = (dir: tmpDir, isTempDir: true)
  else:
    result.userDataDir = (dir: userDataDir, isTempDir: false)

  let (chrome, endpoint) = startChrome(portNo, result.userDataDir.dir,
                                       headlessMode, chromeArguments)
  result.chrome = chrome

  let (address, port, path) = parseEndpoint(endpoint)
  result.loop = newLoop()
  result.startPollLoop()

  var openFuture = newFuture[bool]()
  result.ws = connectWs(
    result.loop,
    address,
    port,
    path,
    host = address & ":" & $port,
    onOpen = proc(ws: WsConnection) =
      if not openFuture.finished:
        openFuture.complete(true),
    onMessage = proc(ws: WsConnection, kind: WsFrameKind, data: openArray[byte]) =
      if kind == wsText:
        result.handleWsPacket(data),
    onClose = proc(ws: WsConnection, code: int, reason: string) =
      if not openFuture.finished:
        openFuture.fail(newException(CDPError,
            "WebSocket closed during connect: code " & $code & " " & reason)),
    onError = proc(ws: WsConnection, err: string) =
      if not openFuture.finished:
        openFuture.fail(newException(CDPError, "WebSocket error: " & err))
  )
  discard await openFuture.withTimeout(10000)

proc close*(browser: Browser) {.async.} =
  ## Closes the browser instance, closes the websocket connection, deletes
  ## the user data directory, and terminates the Chrome process (if it is
  ## still running).
  try:
    await browser.closeBrowserDomain()
  except CatchableError:
    discard
  browser.polling = false
  await sleepAsync(50) # let the poll driver observe `polling == false`
  browser.ws.closeWs(1000, "closing")
  browser.loop.close()
  var errorLog: string
  if browser.userDataDir.isTempDir:
    for attempt in 1 .. 3:
      await sleepAsync 1000 # wait for browser to close (3 secs max)
      try:
        browser.userDataDir.dir.removeDir()
        break
      except OSError as e:
        if attempt == 3:
          errorLog.add("[OsError] error deleting user data dir: " &
              browser.userDataDir.dir & "message: " & e.msg)
  browser.chrome.terminate()
  browser.chrome.close()
  if errorLog.len > 0:
    raise newException(OSError, errorLog)

proc newTab*(browser: Browser): Future[Tab] {.async.} =
  ## Creates a new tab (Page) in the browser instance and returns a `Tab` object.
  let
    targetId = await browser.createTarget()
    sessionId = await browser.attachToTarget(targetId)
  result = Tab(browser: browser, sessionId: sessionId)

proc addGlobalEventCallback*(browser: Browser; event: ProtocolEvent; cb: EventCallback) =
  ## Adds a callback function to the global event table for the specified event.
  ## The callback function will be called when the specified event is received.
  ##
  ## Remove the callback via `deleteGlobalEventCallback` when it is no longer needed.
  ##
  ## **Note:** Currently, there can only be one callback function per event in the
  ## global event table.
  browser.globalEventTable[event] = cb

proc addSessionEventCallback*(browser: Browser; sessionId: SessionId;
                              event: ProtocolEvent; cb: EventCallback) =
  ## Adds a callback function to the session event table for the specified event.
  ## The callback function will be called when the specified event is received.
  ##
  ## Remove the callback via `deleteSessionEventCallback` when it is no longer needed.
  ##
  ## **Note:** Currently, there can only be one callback function per event, *per
  ## session* in the session event table.
  if not browser.sessionEventTable.hasKey(sessionId):
    browser.sessionEventTable[sessionId] = initTable[ProtocolEvent, EventCallback]()
  browser.sessionEventTable[sessionId][event] = cb

proc waitForGlobalEvent*(browser: Browser; event: ProtocolEvent): Future[JsonNode] {.async.} =
  ## Returns a `Future` that completes when the specified global event is received.
  ##
  ## **Note:** This procedure will override the callback function in the global
  ## event table if one already exists for the specified event.
  let future = newFuture[JsonNode]()
  browser.addGlobalEventCallback(event, proc(jsn: JsonNode) {.async.} =
    future.complete(jsn))
  result = await future
  browser.globalEventTable.del(event)

proc waitForSessionEvent*(browser: Browser; sessionId: string;
                          event: ProtocolEvent): Future[JsonNode] {.async.} =
  ## Returns a `Future` that completes when the specified session event is received.
  ##
  ## **Note:** This procedure will override the callback function in the session
  ## event table if one already exists for the specified event.
  let future = newFuture[JsonNode]()
  browser.addSessionEventCallback(sessionId, event, proc(jsn: JsonNode) {.async.} =
    future.complete(jsn))
  result = await future
  browser.sessionEventTable[sessionId].del(event)

proc deleteGlobalEventCallback*(browser: Browser; event: ProtocolEvent) =
  ## Removes the callback function from the global event table for the specified event.
  if browser.globalEventTable.hasKey(event):
    browser.globalEventTable.del(event)

proc deleteSessionEventCallback*(browser: Browser; sessionId: SessionId; event: ProtocolEvent) =
  ## Removes the callback function from the session event table for the specified event.
  if browser.sessionEventTable.hasKey(sessionId):
    if browser.sessionEventTable[sessionId].hasKey(event):
      browser.sessionEventTable[sessionId].del(event)