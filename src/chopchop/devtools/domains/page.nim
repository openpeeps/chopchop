## This module provides a direct mapping of CDP events and commands for the
## `Page Domain <https://chromedevtools.github.io/devtools-protocol/1-3/Page/>`_.
## Actions and events related to the inspected page belong to the page domain.

import std/[json, asyncdispatch, options]
import pkg/openparser/json
import ../core/base

type
  Page* {.pure.} = enum ## **Page Domain** events
    domContentEventFired = "Page.domContentEventFired"
    fileChooserOpened = "Page.fileChooserOpened"
    frameAttached = "Page.frameAttached"
    frameDetached = "Page.frameDetached"
    frameNavigated = "Page.frameNavigated"
    interstitialHidden = "Page.interstitialHidden"
    interstitialShown = "Page.interstitialShown"
    javascriptDialogClosed = "Page.javascriptDialogClosed"
    javascriptDialogOpening = "Page.javascriptDialogOpening"
    lifecycleEvent = "Page.lifecycleEvent"
    loadEventFired = "Page.loadEventFired"
    windowOpen = "Page.windowOpen"

  NavigateParams* = object
    url*: string

  NavigateResult* = object
    frameId*: string
    errorText*: Option[string]

  CaptureScreenshotParams* = object
    format*: string
    quality*: Option[int]
    fullPage*: Option[bool]

  CaptureScreenshotResult* = object
    data*: string

  AddScriptToEvaluateOnNewDocumentResult* = object
    identifier*: string

  HandleJavaScriptDialogParams* = object
    accept*: bool
    promptText*: Option[string]

proc addScriptToEvaluateOnNewDocument*(tab: Tab; source: string): Future[string] {.async.} =
  ## `Page.addScriptToEvaluateOnNewDocument
  ## <https://chromedevtools.github.io/devtools-protocol/1-3/Page/#method-addScriptToEvaluateOnNewDocument>`_
  ## Evaluates given script in every frame upon creation (before loading frame's
  ## scripts). Returns the script `identifier`.
  let resp = await tab.sendCommand("Page.addScriptToEvaluateOnNewDocument",
      %*{"source": source})
  result = fromJson($resp["result"], AddScriptToEvaluateOnNewDocumentResult).identifier

proc captureScreenshot*(tab: Tab; params: CaptureScreenshotParams): Future[string] {.async.} =
  ## `Page.captureScreenshot
  ## <https://chromedevtools.github.io/devtools-protocol/1-3/Page/#method-captureScreenshot>`_
  ## Capture page screenshot. Returns the base64-encoded image data.
  let resp = await tab.sendCommand("Page.captureScreenshot", params)
  result = fromJson($resp["result"], CaptureScreenshotResult).data

proc captureScreenshot*(tab: Tab): Future[string] {.async.} =
  result = await tab.captureScreenshot(CaptureScreenshotParams(format: "png"))

proc closePage*(tab: Tab) {.async.} =
  ## `Page.close <https://chromedevtools.github.io/devtools-protocol/1-3/Page/#method-close>`_
  ## Tries to close page, running its beforeunload hooks, if any.
  discard await tab.sendCommand("Page.close")

proc disablePageDomain*(tab: Tab) {.async.} =
  ## `Page.disable <https://chromedevtools.github.io/devtools-protocol/1-3/Page/#method-disable>`_
  ## Disables page domain notifications.
  discard await tab.sendCommand("Page.disable")

proc enablePageDomain*(tab: Tab) {.async.} =
  ## `Page.enable <https://chromedevtools.github.io/devtools-protocol/1-3/Page/#method-enable>`_
  ## Enables page domain notifications.
  discard await tab.sendCommand("Page.enable")

proc handleJavaScriptDialog*(tab: Tab; params: HandleJavaScriptDialogParams) {.async.} =
  ## `Page.handleJavaScriptDialog
  ## <https://chromedevtools.github.io/devtools-protocol/1-3/Page/#method-handleJavaScriptDialog>`_
  ## Accepts or dismisses a JavaScript initiated dialog (alert, confirm, prompt,
  ## or onbeforeunload).
  discard await tab.sendCommand("Page.handleJavaScriptDialog", params)

proc handleJavaScriptDialog*(tab: Tab; accept: bool) {.async.} =
  await tab.handleJavaScriptDialog(HandleJavaScriptDialogParams(accept: accept))

proc navigate*(tab: Tab; url: string): Future[NavigateResult] {.async.} =
  ## `Page.navigate <https://chromedevtools.github.io/devtools-protocol/1-3/Page/#method-navigate>`_
  ## Navigates current page to the given URL.
  let resp = await tab.sendCommand("Page.navigate", NavigateParams(url: url))
  result = fromJson($resp["result"], NavigateResult)

proc reload*(tab: Tab) {.async.} =
  ## `Page.reload <https://chromedevtools.github.io/devtools-protocol/1-3/Page/#method-reload>`_
  ## Reloads given page.
  discard await tab.sendCommand("Page.reload")

proc bringToFront*(tab: Tab) {.async.} =
  ## `Page.bringToFront <https://chromedevtools.github.io/devtools-protocol/1-3/Page/#method-bringToFront>`_
  ## Brings page to front (activates tab).
  discard await tab.sendCommand("Page.bringToFront")