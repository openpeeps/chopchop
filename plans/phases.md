# chopchop Development Phases

## Phase 1: Scraping Power-Ups

High-impact, low-effort features that fill the biggest gaps for web scraping.

| Feature | Effort | Priority |
|---|---|---|
| `addInitScript()` — inject JS before page scripts run | Small | High |
| Cookie management — `getCookies()`, `setCookies()`, `deleteCookies()` | Small | High |
| `select()` / option handling — interact with `<select>` elements | Small | High |
| `evaluateHandle()` — return JS handles with `objectId` instead of serialized values | Small | Medium |
| `BrowserContext` — isolated sessions (separate cookies/storage per context) | Medium | High |
| Network idle wait — `waitUntil: NetworkIdle` for pages with lazy content | Medium | High |
| Local/session storage — read/write via evaluate helpers | Small | Medium |
| Frame support — `page.frames()`, `frame.querySelector()` | Medium | Medium |

## Phase 2: Automation Fundamentals

Real browser automation beyond read-only scraping.

| Feature | Effort | Priority |
|---|---|---|
| Mouse actions — click, dblclick, hover, dragAndDrop, scroll via CDP Input domain | Medium | High |
| Keyboard actions — special keys, key combos, proper keyDown/keyUp/char sequencing | Medium | High |
| Alert/dialog handling — auto-accept or capture alert/confirm/prompt | Medium | High |
| Console capture — listen for `Runtime.consoleAPICalled` events | Small | High |
| Network interception — `page.route()`, `page.unroute()`, mock API responses | Medium | High |
| Device emulation — viewport, device pixel ratio, user agent, geolocation | Small | Medium |
| File upload — `input.setInputFiles(paths)` via CDP `DOM.setFileInputFiles` | Small | Medium |

## Phase 3: Testing Infrastructure

Make chopchop a proper UI testing tool.

| Feature | Effort | Priority |
|---|---|---|
| Locator API — `page.locator()`, `getByText()`, `getByRole()` with auto-retry/auto-wait | Large | High |
| Auto-waiting — all actions implicitly wait for element to be ready (Playwright model) | Medium | High |
| Assertions — `expect().toHaveText()`, `toBeVisible()`, `toHaveAttribute()` with polling | Medium | High |
| Screenshot diffing — compare against baselines for visual regression | Medium | Medium |
| Test fixtures — browser/page lifecycle managed per test | Medium | Medium |
| Trace viewer — record traces (screenshots, console, network, etc.) | Large | Low |

## Phase 4: Advanced & Performance

| Feature | Effort | Priority |
|---|---|---|
| Multi-page / popup handling — detect and switch to new tabs/windows | Medium | High |
| Worker / service worker — interact with Web Workers | Large | Low |
| Coverage collection — JS/CSS code coverage via CDP Profiler domain | Small | Low |
| Performance metrics — FCP, DCL, LCP via CDP Performance domain | Small | Medium |
| Video recording — screencast-based test recording | Large | Low |
| Parallel execution — run tests across multiple contexts concurrently | Medium | Medium |
| Browser download — auto-download Chromium (like Playwright install) | Medium | Medium |

## Architecture Considerations

1. **Locator abstraction** — A `Locator` type (not tied to a specific element) that re-queries the DOM on every action. Enables auto-wait, auto-retry, and chaining.

2. **BrowserContext** — Isolation layer wrapping CDP's `Target.createBrowserContext`. Cookies/storage isolated per-context, essential for multi-session scraping.

3. **Auto-waiting strategy** — Decide early: should `click()` automatically wait for the element to be visible/stable? Playwright's approach (30s timeout, retry on actionability checks) is the gold standard.
