## This module provides a direct mapping of CDP events and commands for the
## `Emulation Domain <https://chromedevtools.github.io/devtools-protocol/1-3/Emulation/>`_.
## This domain emulates different environments for the page.

import std/[json, asyncdispatch]
import pkg/openparser/json
import ../core/base

type
  SetDeviceMetricsOverrideParams* = object
    width*: int
    height*: int
    deviceScaleFactor*: float
    mobile*: bool

  SetUserAgentOverrideParams* = object
    userAgent*: string

  SetGeolocationOverrideParams* = object
    latitude*: float
    longitude*: float
    accuracy*: float

proc setDeviceMetricsOverride*(tab: Tab; params: SetDeviceMetricsOverrideParams) {.async.} =
  ## `Emulation.setDeviceMetricsOverride
  ## <https://chromedevtools.github.io/devtools-protocol/1-3/Emulation/#method-setDeviceMetricsOverride>`_
  ## Overrides the values of device screen dimensions.
  discard await tab.sendCommand("Emulation.setDeviceMetricsOverride", params)

proc setDeviceMetricsOverride*(tab: Tab; width, height: int;
                               deviceScaleFactor: float; mobile: bool) {.async.} =
  discard await tab.sendCommand("Emulation.setDeviceMetricsOverride",
      SetDeviceMetricsOverrideParams(width: width, height: height,
          deviceScaleFactor: deviceScaleFactor, mobile: mobile))

proc setUserAgentOverride*(tab: Tab; params: SetUserAgentOverrideParams) {.async.} =
  ## `Emulation.setUserAgentOverride
  ## <https://chromedevtools.github.io/devtools-protocol/1-3/Emulation/#method-setUserAgentOverride>`_
  ## Allows overriding user agent with the given string.
  discard await tab.sendCommand("Emulation.setUserAgentOverride", params)

proc setUserAgentOverride*(tab: Tab; userAgent: string) {.async.} =
  discard await tab.sendCommand("Emulation.setUserAgentOverride",
      SetUserAgentOverrideParams(userAgent: userAgent))

proc setGeolocationOverride*(tab: Tab; params: SetGeolocationOverrideParams) {.async.} =
  ## `Emulation.setGeolocationOverride
  ## <https://chromedevtools.github.io/devtools-protocol/1-3/Emulation/#method-setGeolocationOverride>`_
  ## Overrides the Geolocation Position or Error.
  discard await tab.sendCommand("Emulation.setGeolocationOverride", params)

proc setGeolocationOverride*(tab: Tab; latitude, longitude, accuracy: float) {.async.} =
  discard await tab.sendCommand("Emulation.setGeolocationOverride",
      SetGeolocationOverrideParams(latitude: latitude, longitude: longitude, accuracy: accuracy))