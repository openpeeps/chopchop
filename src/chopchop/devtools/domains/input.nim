## This module provides a direct mapping of CDP events and commands for the
## `Input Domain <https://chromedevtools.github.io/devtools-protocol/1-3/Input/>`_.

import std/[json, asyncdispatch, options]
import pkg/openparser/json
import ../core/base

type
  DispatchKeyEventParams* = object
    `type`*: string
    key*: Option[string]
    code*: Option[string]
    text*: Option[string]
    windowsVirtualKeyCode*: Option[int]

  DispatchMouseEventParams* = object
    `type`*: string
    x*: float
    y*: float
    button*: Option[string]
    buttons*: Option[int]
    clickCount*: Option[int]

proc dispatchKeyEvent*(tab: Tab; params: DispatchKeyEventParams) {.async.} =
  ## `Input.dispatchKeyEvent
  ## <https://chromedevtools.github.io/devtools-protocol/1-3/Input/#method-dispatchKeyEvent>`_
  ## Dispatches a key event to the page.
  discard await tab.sendCommand("Input.dispatchKeyEvent", params)

proc dispatchKeyEvent*(tab: Tab; `type`: string) {.async.} =
  discard await tab.sendCommand("Input.dispatchKeyEvent", DispatchKeyEventParams(`type`: `type`))

proc dispatchMouseEvent*(tab: Tab; params: DispatchMouseEventParams) {.async.} =
  ## `Input.dispatchMouseEvent
  ## <https://chromedevtools.github.io/devtools-protocol/1-3/Input/#method-dispatchMouseEvent>`_
  ## Dispatches a mouse event to the page.
  discard await tab.sendCommand("Input.dispatchMouseEvent", params)

proc dispatchMouseEvent*(tab: Tab; `type`: string; x, y: float) {.async.} =
  discard await tab.sendCommand("Input.dispatchMouseEvent",
      DispatchMouseEventParams(`type`: `type`, x: x, y: y))

proc setIgnoreInputEvents*(tab: Tab; ignore: bool) {.async.} =
  ## `Input.setIgnoreInputEvents
  ## <https://chromedevtools.github.io/devtools-protocol/1-3/Input/#method-setIgnoreInputEvents>`_
  ## Ignores input events (useful while debugging).
  discard await tab.sendCommand("Input.setIgnoreInputEvents", %*{"ignore": ignore})