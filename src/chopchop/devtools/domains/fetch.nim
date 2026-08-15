## This module provides a direct mapping of CDP events and commands for the
## `Fetch Domain <https://chromedevtools.github.io/devtools-protocol/1-3/Fetch/>`_.

import std/[json, asyncdispatch, options]
import pkg/openparser/json
import ../core/base

type
  Fetch* {.pure.} = enum ## **Fetch Domain** events
    authRequired = "Fetch.authRequired"
    requestPaused = "Fetch.requestPaused"

  FetchRequestPattern* = object
    urlPattern*: string
    requestStage*: Option[string]

  FetchEnableParams* = object
    patterns*: seq[FetchRequestPattern]

  FulfillRequestParams* = object
    requestId*: string
    responseCode*: int
    body*: Option[string]
    responseHeaders*: Option[seq[HeaderEntry]]

  HeaderEntry* = object
    name*: string
    value*: string

proc continueRequest*(tab: Tab; requestId: string) {.async.} =
  ## `Fetch.continueRequest
  ## <https://chromedevtools.github.io/devtools-protocol/1-3/Fetch/#method-continueRequest>`_
  ## Continues the request, optionally modifying some of its parameters.
  discard await tab.sendCommand("Fetch.continueRequest", %*{"requestId": requestId})

proc disableFetchDomain*(tab: Tab) {.async.} =
  ## `Fetch.disable
  ## <https://chromedevtools.github.io/devtools-protocol/1-3/Fetch/#method-disable>`_
  ## Disables the fetch domain.
  discard await tab.sendCommand("Fetch.disable")

proc enableFetchDomain*(tab: Tab; params: FetchEnableParams) {.async.} =
  ## `Fetch.enable <https://chromedevtools.github.io/devtools-protocol/1-3/Fetch/#method-enable>`_
  ## Enables issuing of requestPaused events. A request will be paused until
  ## client calls one of failRequest, fulfillRequest or continueRequest.
  discard await tab.sendCommand("Fetch.enable", params)

proc enableFetchDomain*(tab: Tab) {.async.} =
  discard await tab.sendCommand("Fetch.enable",
      FetchEnableParams(patterns: @[FetchRequestPattern(urlPattern: "*")]))

proc failRequest*(tab: Tab; requestId, errorReason: string) {.async.} =
  ## `Fetch.failRequest
  ## <https://chromedevtools.github.io/devtools-protocol/1-3/Fetch/#method-failRequest>`_
  ## Causes the request to fail with specified reason.
  discard await tab.sendCommand("Fetch.failRequest",
      %*{"requestId": requestId, "errorReason": errorReason})

proc fulfillRequest*(tab: Tab; params: FulfillRequestParams) {.async.} =
  ## `Fetch.fulfillRequest
  ## <https://chromedevtools.github.io/devtools-protocol/1-3/Fetch/#method-fulfillRequest>`_
  ## Provides response to the request.
  discard await tab.sendCommand("Fetch.fulfillRequest", params)