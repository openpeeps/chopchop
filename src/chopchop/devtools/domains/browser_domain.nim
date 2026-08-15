## This module provides a direct mapping of CDP events and commands for the
## `Browser Domain <https://chromedevtools.github.io/devtools-protocol/1-3/Browser/>`_.
## **Browser Domain** defines methods and events for browser managing.

import std/[json, asyncdispatch]
import ../core/base

proc closeBrowserDomain*(browser: Browser) {.async.} =
  ## `Browser.close
  ## <https://chromedevtools.github.io/devtools-protocol/1-3/Browser/#method-close>`_
  ## Close browser gracefully.
  discard await browser.sendCommand("Browser.close")

proc getVersion*(browser: Browser): Future[JsonNode] {.async.} =
  ## `Browser.getVersion
  ## <https://chromedevtools.github.io/devtools-protocol/1-3/Browser/#method-getVersion>`_
  ## Returns version information.
  result = await browser.sendCommand("Browser.getVersion")