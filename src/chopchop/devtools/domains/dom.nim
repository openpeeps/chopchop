## This module provides a direct mapping of CDP events and commands for the
## `DOM Domain <https://chromedevtools.github.io/devtools-protocol/1-3/DOM/>`_.
## The **DOM Domain** exposes DOM read/write operations.

import std/[json, asyncdispatch, options]
import pkg/openparser/json
import ../core/base

type
  DOM* {.pure.} = enum ## **DOM Domain** events
    attributeModified = "DOM.attributeModified"
    attributeRemoved = "DOM.attributeRemoved"
    characterDataModified = "DOM.characterDataModified"
    childNodeCountUpdated = "DOM.childNodeCountUpdated"
    childNodeInserted = "DOM.childNodeInserted"
    childNodeRemoved = "DOM.childNodeRemoved"
    documentUpdated = "DOM.documentUpdated"
    setChildNodes = "DOM.setChildNodes"

  QuerySelectorParams* = object
    nodeId*: int
    selector*: string

  QuerySelectorResult* = object
    nodeId*: int

  QuerySelectorAllParams* = object
    nodeId*: int
    selector*: string

  QuerySelectorAllResult* = object
    nodeIds*: seq[int]

  GetOuterHTMLParams* = object
    nodeId*: int

  GetOuterHTMLResult* = object
    outerHTML*: string

  RemoteObject* = object
    objectId*: Option[string]
    `type`*: string
    value*: Option[JsonNode]

  ResolveNodeParams* = object
    nodeId*: int

  ResolveNodeResult* = object
    remoteObject*: RemoteObject

proc renameHook*(v: ResolveNodeResult, fieldName: var string) =
  ## The CDP field is named `object`; `object` is a Nim keyword so the Nim
  ## field is `remoteObject`. Map between the two for parse/serialize.
  if fieldName == "object":
    fieldName = "remoteObject"
  elif fieldName == "remoteObject":
    fieldName = "object"

type
  SetFileInputFilesParams* = object
    nodeId*: int
    files*: seq[string]

proc getDocument*(tab: Tab): Future[int] {.async.} =
  ## `DOM.getDocument
  ## <https://chromedevtools.github.io/devtools-protocol/1-3/DOM/#method-getDocument>`_
  ## Returns the root DOM node (and optionally the subtree) to the caller.
  ## Implicitly enables the DOM domain events for the current target.
  ## Returns the `nodeId` of the document root.
  ##
  ## The response's DOM tree is too large and irregular to map onto a typed
  ## object, so the root `nodeId` is read directly from the JSON envelope.
  let resp = await tab.sendCommand("DOM.getDocument")
  result = resp["result"]["root"]["nodeId"].getInt()

proc getOuterHTML*(tab: Tab; params: GetOuterHTMLParams): Future[string] {.async.} =
  ## `DOM.getOuterHTML
  ## <https://chromedevtools.github.io/devtools-protocol/1-3/DOM/#method-getOuterHTML>`_
  ## Returns node's HTML markup.
  let resp = await tab.sendCommand("DOM.getOuterHTML", params)
  result = fromJson($resp["result"], GetOuterHTMLResult).outerHTML

proc getOuterHTML*(tab: Tab; nodeId: int): Future[string] {.async.} =
  result = await tab.getOuterHTML(GetOuterHTMLParams(nodeId: nodeId))

proc querySelector*(tab: Tab; params: QuerySelectorParams): Future[int] {.async.} =
  ## `DOM.querySelector
  ## <https://chromedevtools.github.io/devtools-protocol/1-3/DOM/#method-querySelector>`_
  ## Executes `querySelector` on a given node. Returns the `nodeId` (0 if not found).
  let resp = await tab.sendCommand("DOM.querySelector", params)
  result = fromJson($resp["result"], QuerySelectorResult).nodeId

proc querySelector*(tab: Tab; nodeId: int; selector: string): Future[int] {.async.} =
  result = await tab.querySelector(QuerySelectorParams(nodeId: nodeId, selector: selector))

proc querySelectorAll*(tab: Tab; params: QuerySelectorAllParams): Future[seq[int]] {.async.} =
  ## `DOM.querySelectorAll
  ## <https://chromedevtools.github.io/devtools-protocol/1-3/DOM/#method-querySelectorAll>`_
  ## Executes `querySelectorAll` on a given node. Returns the list of `nodeId`s.
  let resp = await tab.sendCommand("DOM.querySelectorAll", params)
  result = fromJson($resp["result"], QuerySelectorAllResult).nodeIds

proc querySelectorAll*(tab: Tab; nodeId: int; selector: string): Future[seq[int]] {.async.} =
  result = await tab.querySelectorAll(QuerySelectorAllParams(nodeId: nodeId, selector: selector))

proc resolveNode*(tab: Tab; params: ResolveNodeParams): Future[string] {.async.} =
  ## `DOM.resolveNode
  ## <https://chromedevtools.github.io/devtools-protocol/1-3/DOM/#method-resolveNode>`_
  ## Resolves the JavaScript node object for a given `NodeId`. Returns the
  ## `objectId` (empty string if none).
  let resp = await tab.sendCommand("DOM.resolveNode", params)
  result = ""
  if resp.contains("result"):
    let res = fromJson($resp["result"], ResolveNodeResult)
    if res.remoteObject.objectId.isSome:
      result = res.remoteObject.objectId.get()

proc resolveNode*(tab: Tab; nodeId: int): Future[string] {.async.} =
  result = await tab.resolveNode(ResolveNodeParams(nodeId: nodeId))

proc setFileInputFiles*(tab: Tab; params: SetFileInputFilesParams) {.async.} =
  ## `DOM.setFileInputFiles
  ## <https://chromedevtools.github.io/devtools-protocol/1-3/DOM/#method-setFileInputFiles>`_
  ## Sets files for the given file input element.
  discard await tab.sendCommand("DOM.setFileInputFiles", params)

proc setFileInputFiles*(tab: Tab; nodeId: int; files: seq[string]) {.async.} =
  await tab.setFileInputFiles(SetFileInputFilesParams(nodeId: nodeId, files: files))

proc enableDOMDomain*(tab: Tab) {.async.} =
  ## `DOM.enable <https://chromedevtools.github.io/devtools-protocol/1-3/DOM/#method-enable>`_
  ## Enables the DOM agent for the given page.
  discard await tab.sendCommand("DOM.enable")

proc disableDOMDomain*(tab: Tab) {.async.} =
  ## `DOM.disable <https://chromedevtools.github.io/devtools-protocol/1-3/DOM/#method-disable>`_
  ## Disables the DOM agent for the given page.
  discard await tab.sendCommand("DOM.disable")