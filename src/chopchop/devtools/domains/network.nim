## This module provides a direct mapping of CDP events and commands for the
## `Network Domain <https://chromedevtools.github.io/devtools-protocol/1-3/Network/>`_.
## Network domain allows tracking network activities of the page.

import std/[json, asyncdispatch, options]
import pkg/openparser/json
import ../core/base

type
  Network* {.pure.} = enum ## **Network Domain** events
    dataReceived = "Network.dataReceived"
    eventSourceMessageReceived = "Network.eventSourceMessageReceived"
    loadingFailed = "Network.loadingFailed"
    loadingFinished = "Network.loadingFinished"
    requestServedFromCache = "Network.requestServedFromCache"
    requestWillBeSent = "Network.requestWillBeSent"
    responseReceived = "Network.responseReceived"

  NetworkCookie* = object
    name*: string
    value*: string
    domain*: string
    path*: string
    expires*: float
    size*: int
    httpOnly*: bool
    secure*: bool
    session*: bool
    sameSite*: string

  GetCookiesResult* = object
    cookies*: seq[NetworkCookie]

  SetCookieParams* = object
    name*: string
    value*: string
    url*: Option[string]
    domain*: Option[string]
    path*: Option[string]
    secure*: Option[bool]
    httpOnly*: Option[bool]
    sameSite*: Option[string]
    expires*: Option[float]

  DeleteCookiesParams* = object
    name*: string
    url*: Option[string]
    domain*: Option[string]
    path*: Option[string]

proc clearBrowserCache*(tab: Tab) {.async.} =
  ## `Network.clearBrowserCache
  ## <https://chromedevtools.github.io/devtools-protocol/1-3/Network/#method-clearBrowserCache>`_
  ## Clears browser cache.
  discard await tab.sendCommand("Network.clearBrowserCache")

proc clearBrowserCookies*(tab: Tab) {.async.} =
  ## `Network.clearBrowserCookies
  ## <https://chromedevtools.github.io/devtools-protocol/1-3/Network/#method-clearBrowserCookies>`_
  ## Clears browser cookies.
  discard await tab.sendCommand("Network.clearBrowserCookies")

proc deleteCookies*(tab: Tab; params: DeleteCookiesParams) {.async.} =
  ## `Network.deleteCookies
  ## <https://chromedevtools.github.io/devtools-protocol/1-3/Network/#method-deleteCookies>`_
  ## Deletes browser cookies with matching name and url or domain/path/partitionKey pair.
  discard await tab.sendCommand("Network.deleteCookies", params)

proc deleteCookies*(tab: Tab; name: string) {.async.} =
  discard await tab.sendCommand("Network.deleteCookies", DeleteCookiesParams(name: name))

proc disableNetworkDomain*(tab: Tab) {.async.} =
  ## `Network.disable
  ## <https://chromedevtools.github.io/devtools-protocol/1-3/Network/#method-disable>`_
  ## Disables network tracking, prevents network events from being sent to the client.
  discard await tab.sendCommand("Network.disable")

proc enableNetworkDomain*(tab: Tab) {.async.} =
  ## `Network.enable <https://chromedevtools.github.io/devtools-protocol/1-3/Network/#method-enable>`_
  ## Enables network tracking, network events will now be delivered to the client.
  discard await tab.sendCommand("Network.enable")

proc getCookies*(tab: Tab): Future[seq[NetworkCookie]] {.async.} =
  ## `Network.getCookies
  ## <https://chromedevtools.github.io/devtools-protocol/1-3/Network/#method-getCookies>`_
  ## Returns all browser cookies for the current URL.
  let resp = await tab.sendCommand("Network.getCookies")
  result = fromJson($resp["result"], GetCookiesResult).cookies

proc setCookie*(tab: Tab; params: SetCookieParams) {.async.} =
  ## `Network.setCookie
  ## <https://chromedevtools.github.io/devtools-protocol/1-3/Network/#method-setCookie>`_
  ## Sets a cookie with the given cookie data; may overwrite equivalent cookies
  ## if they exist.
  discard await tab.sendCommand("Network.setCookie", params)