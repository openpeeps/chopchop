## Basic types and procedures for interacting with the Chrome DevTools
## Protocol (CDP), transport handled by powpow's WebSocket client and
## wire JSON handled by openparser/json.

import std/[json, asyncdispatch, tables, osproc]
import pkg/powpow
import pkg/openparser/json

type
  CDPError* = object of CatchableError
  RequestId* = int
  SessionId* = string
  ProtocolEvent* = string
  EventCallback* = proc(data: JsonNode) {.async.}
  ResponseTable* = Table[RequestId, Future[JsonNode]]
  SessionEventTable* = Table[SessionId, Table[ProtocolEvent, EventCallback]]
  GlobalEventTable* = Table[ProtocolEvent, EventCallback]

  Browser* = ref object ## Represents a `Browser` instance. Fields are read-only
                        ## and should not be used directly.
    chrome*: Process
    userDataDir*: tuple[dir: string, isTempDir: bool]
    loop*: Loop
    ws*: WsConnection
    requestId*: RequestId
    responseTable*: ResponseTable
    globalEventTable*: GlobalEventTable
    sessionEventTable*: SessionEventTable
    polling*: bool

  Tab* = ref object ## Represents a `Tab` (Page). Fields are read-only, do not modify.
    browser*: Browser
    sessionId*: SessionId

proc stripNulls*(node: JsonNode): JsonNode =
  ## Recursively removes `null` values from a JSON object/array. Used to drop
  ## `none` `Option` fields from serialized CDP params so unset optional
  ## parameters are omitted from the wire message. Internal helper; exported
  ## for testing.
  case node.kind
  of JObject:
    result = newJObject()
    for k, v in node:
      if v.kind != JNull:
        result[k] = stripNulls(v)
  of JArray:
    result = newJArray()
    for v in node:
      let stripped = stripNulls(v)
      if stripped.kind != JNull:
        result.add(stripped)
  else:
    result = node

proc sendCommand*(browser: Browser; mthd: string; params: JsonNode): Future[JsonNode] {.async.} =
  ## Sends a command with parameters to the CDP endpoint (browser-level).
  browser.requestId += 1
  if browser.requestId > 9999: browser.requestId = 1
  let future = newFuture[JsonNode]()
  browser.responseTable[browser.requestId] = future
  var msg = %*{"id": browser.requestId, "method": mthd}
  if params != nil:
    msg["params"] = params
  browser.ws.sendText(toJson(msg))
  result = await future

proc sendCommand*[T](browser: Browser; mthd: string; params: T): Future[JsonNode] {.async.} =
  ## Typed version of `sendCommand`: serializes a Nim object to JSON via
  ## openparser, omitting unset (`none`) optional fields.
  result = await browser.sendCommand(mthd, toJsonNode(params).stripNulls())

proc sendCommand*(browser: Browser; mthd: string): Future[JsonNode] {.async.} =
  ## Sends a command without parameters (browser-level).
  browser.requestId += 1
  if browser.requestId > 9999: browser.requestId = 1
  let future = newFuture[JsonNode]()
  browser.responseTable[browser.requestId] = future
  browser.ws.sendText(toJson(%*{"id": browser.requestId, "method": mthd}))
  result = await future

proc sendCommand*(tab: Tab; mthd: string; params: JsonNode): Future[JsonNode] {.async.} =
  ## Sends a command with parameters to the CDP endpoint (tab-level,
  ## includes the session id).
  tab.browser.requestId += 1
  if tab.browser.requestId > 9999: tab.browser.requestId = 1
  let future = newFuture[JsonNode]()
  tab.browser.responseTable[tab.browser.requestId] = future
  var msg = %*{"id": tab.browser.requestId, "method": mthd, "sessionId": tab.sessionId}
  if params != nil:
    msg["params"] = params
  tab.browser.ws.sendText(toJson(msg))
  result = await future

proc sendCommand*[T](tab: Tab; mthd: string; params: T): Future[JsonNode] {.async.} =
  ## Typed version of `sendCommand` for tab-level commands.
  result = await tab.sendCommand(mthd, toJsonNode(params).stripNulls())

proc sendCommand*(tab: Tab; mthd: string): Future[JsonNode] {.async.} =
  ## Sends a command without parameters (tab-level).
  tab.browser.requestId += 1
  if tab.browser.requestId > 9999: tab.browser.requestId = 1
  let future = newFuture[JsonNode]()
  tab.browser.responseTable[tab.browser.requestId] = future
  tab.browser.ws.sendText(toJson(%*{"id": tab.browser.requestId, "method": mthd,
                                     "sessionId": tab.sessionId}))
  result = await future