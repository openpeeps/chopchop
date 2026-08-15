## This module provides a direct mapping of CDP events and commands for the
## `Runtime Domain <https://chromedevtools.github.io/devtools-protocol/1-3/Runtime/>`_.
## Runtime domain exposes JavaScript runtime by means of remote evaluation and
## mirror objects.

import std/[json, asyncdispatch, options]
import pkg/openparser/json
import ../core/base

type
  Runtime* {.pure.} = enum ## **Runtime Domain** events
    consoleAPICalled = "Runtime.consoleAPICalled"
    executionContextCreated = "Runtime.executionContextCreated"
    executionContextDestroyed = "Runtime.executionContextDestroyed"
    executionContextCleared = "Runtime.executionContextCleared"
    exceptionThrown = "Runtime.exceptionThrown"
    exceptionRevoked = "Runtime.exceptionRevoked"
    inspectRequested = "Runtime.inspectRequested"

  EvaluateParams* = object
    expression*: string
    returnByValue*: Option[bool]
    awaitPromise*: Option[bool]

  CallFunctionOnParams* = object
    functionDeclaration*: string
    objectId*: string
    returnByValue*: Option[bool]
    awaitPromise*: Option[bool]

proc callFunctionOn*(tab: Tab; params: CallFunctionOnParams): Future[JsonNode] {.async.} =
  ## `Runtime.callFunctionOn
  ## <https://chromedevtools.github.io/devtools-protocol/1-3/Runtime/#method-callFunctionOn>`_
  ## Calls function with given declaration on the given object. Returns the raw
  ## CDP response so callers can inspect the resulting `RemoteObject`.
  result = await tab.sendCommand("Runtime.callFunctionOn", params)

proc callFunctionOn*(tab: Tab; functionDeclaration: string): Future[JsonNode] {.async.} =
  result = await tab.callFunctionOn(CallFunctionOnParams(functionDeclaration: functionDeclaration))

proc disableRuntimeDomain*(tab: Tab) {.async.} =
  ## `Runtime.disable <https://chromedevtools.github.io/devtools-protocol/1-3/Runtime/#method-disable>`_
  ## Disables reporting of execution contexts creation.
  discard await tab.sendCommand("Runtime.disable")

proc enableRuntimeDomain*(tab: Tab) {.async.} =
  ## `Runtime.enable <https://chromedevtools.github.io/devtools-protocol/1-3/Runtime/#method-enable>`_
  ## Enables reporting of execution contexts creation by means of
  ## `executionContextCreated` event.
  discard await tab.sendCommand("Runtime.enable")

proc evaluate*(tab: Tab; params: EvaluateParams): Future[JsonNode] {.async.} =
  ## `Runtime.evaluate <https://chromedevtools.github.io/devtools-protocol/1-3/Runtime/#method-evaluate>`_
  ## Evaluates expression on global object. Returns the raw CDP response so
  ## callers can inspect the resulting `RemoteObject` and `exceptionDetails`.
  result = await tab.sendCommand("Runtime.evaluate", params)

proc evaluate*(tab: Tab; expression: string): Future[JsonNode] {.async.} =
  result = await tab.evaluate(EvaluateParams(expression: expression))