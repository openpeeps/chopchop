import std/[asyncdispatch, strutils]
import ../src/chopchop

when isMainModule:
  proc main() {.async.} =
    let browser = await launchBrowser()
    try:
      let page = await browser.newPage()
      await page.goto("https://example.com")

      echo "=== Cookies ==="
      echo "Before: ", await page.cookies()

      await page.setCookie(Cookie(name: "mykey", value: "myvalue"))
      let ck1 = await page.cookies()
      echo "After setCookie: ", ck1.len, " cookie(s)"
      for c in ck1:
        echo "  $1 = $2" % [c.name, c.value]

      await page.deleteCookie("mykey")
      echo "After deleteCookie: ", (await page.cookies()).len

      await page.setCookie(Cookie(name: "ck1", value: "v1"))
      await page.setCookie(Cookie(name: "ck2", value: "v2"))
      echo "Before clear: ", (await page.cookies()).len
      await page.clearCookies()
      echo "After clear:   ", (await page.cookies()).len

      echo "\n=== localStorage ==="
      echo "Get 'testKey': '", await page.localStorage("testKey"), "'"
      await page.setLocalStorage("testKey", "hello")
      echo "After set:    '", await page.localStorage("testKey"), "'"

      echo "\n=== sessionStorage ==="
      echo "Get 'sessionKey': '", await page.sessionStorage("sessionKey"), "'"
      await page.setSessionStorage("sessionKey", "world")
      echo "After set:       '", await page.sessionStorage("sessionKey"), "'"

    finally:
      await browser.close()

  waitFor main()
