## This module provides a direct mapping of CDP events and commands for the
## `Target Domain <https://chromedevtools.github.io/devtools-protocol/1-3/Target/>`_.
## The **Target Domain** supports additional targets discovery and allows to
## attach to them.

import std/[json, asyncdispatch, options]
import pkg/openparser/json
import ../core/base

type
  Target* {.pure.} = enum ## **Target Domain** events
    receivedMessageFromTarget = "Target.receivedMessageFromTarget"
    targetCreated = "Target.targetCreated"
    targetDestroyed = "Target.targetDestroyed"
    targetCrashed = "Target.targetCrashed"
    targetInfoChanged = "Target.targetInfoChanged"

  CreateTargetParams* = object
    url*: string
    browserContextId*: Option[string]

  DisposeBrowserContextParams* = object
    browserContextId*: string

  CreateBrowserContextResult* = object
    browserContextId*: string

  CreateTargetResult* = object
    targetId*: string

  AttachToTargetResult* = object
    sessionId*: string

proc createBrowserContext*(browser: Browser): Future[string] {.async.} =
  ## `Target.createBrowserContext
  ## <https://chromedevtools.github.io/devtools-protocol/1-3/Target/#method-createBrowserContext>`_
  ## Creates a new *browser context*. Similar to an incognito profile but you
  ## can have more than one. Returns the new `browserContextId`.
  let resp = await browser.sendCommand("Target.createBrowserContext")
  result = fromJson($resp["result"], CreateBrowserContextResult).browserContextId

proc createTarget*(browser: Browser; params: CreateTargetParams): Future[string] {.async.} =
  ## `Target.createTarget <https://chromedevtools.github.io/devtools-protocol/1-3/Target/#method-createTarget>`_
  ## Creates a new *page* in the given browser context. Returns the `targetId`.
  let resp = await browser.sendCommand("Target.createTarget", params)
  result = fromJson($resp["result"], CreateTargetResult).targetId

proc createTarget*(browser: Browser; url = ""): Future[string] {.async.} =
  ## Creates a new *page*. Passing `""` to `url` creates a blank page
  ## (`about:blank`). Returns the `targetId`.
  result = await browser.createTarget(CreateTargetParams(url: url))

proc attachToTarget*(browser: Browser; targetId: string): Future[string] {.async.} =
  ## `Target.attachToTarget <https://chromedevtools.github.io/devtools-protocol/1-3/Target/#method-attachToTarget>`_
  ## Attaches to the *target* with the given `targetId`.
  ## `flatten` parameter is forced `true` to simplify the API.
  let resp = await browser.sendCommand("Target.attachToTarget",
      %*{"targetId": targetId, "flatten": true})
  result = fromJson($resp["result"], AttachToTargetResult).sessionId

proc disposeBrowserContext*(browser: Browser; browserContextId: string) {.async.} =
  ## `Target.disposeBrowserContext
  ## <https://chromedevtools.github.io/devtools-protocol/1-3/Target/#method-disposeBrowserContext>`_
  ## Deletes a *browser context*. All the belonging pages will be closed
  ## without calling their beforeunload hooks.
  discard await browser.sendCommand("Target.disposeBrowserContext",
      DisposeBrowserContextParams(browserContextId: browserContextId))