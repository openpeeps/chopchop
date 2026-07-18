import std/[asyncdispatch, strutils]
import ../src/chopchop

when isMainModule:
  proc main() {.async.} =
    let browser = await launchBrowser()
    try:
      let page = await browser.newPage()

      echo "=== Network Interception ==="
      var requests: seq[Route] = @[]

      await page.route("*", proc(r: Route): Future[void] {.closure, async.} =
        echo "  [>] $1 $2" % [r.httpMethod, r.url]
        requests.add(r)
        await r.continueRequest()
      )

      await page.goto("https://example.com")
      echo "Total requests: ", requests.len

      echo "\n=== Abort Images ==="
      let page2 = await browser.newPage()
      await page2.route("*", proc(r: Route): Future[void] {.closure, async.} =
        if r.httpMethod == "GET" and (r.url.endsWith(".png") or r.url.endsWith(".jpg")):
          echo "  [X] Blocked image: ", r.url
          await r.abortRequest()
        else:
          await r.continueRequest()
      )
      await page2.goto("https://example.com")
      echo "Done (images blocked if any)"

      echo "\n=== Fulfill with Mock ==="
      let page3 = await browser.newPage()
      await page3.route("**/*.css", proc(r: Route): Future[void] {.closure, async.} =
        await r.fulfillRequest(
          status = 200,
          body = "body { background: red !important; }",
          headers = @[("content-type", "text/css")]
        )
      )
      await page3.goto("https://example.com")
      echo "CSS mocked (page has red background)"

    finally:
      await browser.close()

  waitFor main()
