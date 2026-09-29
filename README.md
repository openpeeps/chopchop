<p align="center">ChopChop &mdash; A browser automation library around<br>
  Chrome DevTools Protocol</p>

<p align="center">
  <code>nimble install chopchop</code>
</p>

<p align="center">
  <a href="https://openpeeps.github.io/chopchop">API reference</a><br>
  <img src="https://github.com/openpeeps/chopchop/workflows/test/badge.svg" alt="Github Actions">  <img src="https://github.com/openpeeps/chopchop/workflows/docs/badge.svg" alt="Github Actions">
</p>

## Key Features
- High-level library based on [ChromeDevToolsProtocol](https://github.com/Niminem/ChromeDevToolsProtocol) package
- **Browser automation** - launch Chrome, navigate pages, extract content
- **DOM querying** - `querySelector` / `querySelectorAll` with full element access
- **Mouse & keyboard** - click, double-click, hover, drag & drop, type text, press keys
- **JavaScript evaluation** - `evaluate` / `evaluateHandle` with return values
- **Navigation control** - `waitForNavigation`, `waitForSelector`, multiple `waitUntil` modes (Load, DOMContentLoaded, NetworkIdle)
- **Device emulation** - viewport, user agent, geolocation
- **Cookie management** - get, set, delete, clear cookies
- **Local & session storage** - read/write via CDP
- **Dialog handling** - alert/confirm/prompt auto-accept or custom handlers
- **Console capture** - listen to browser console messages
- **Network interception** - route, fulfill, abort requests with glob patterns
- **File uploads** - `setInputFiles` on file inputs
- **Select/dropdown** - select by value, label, or index
- **Screenshots** - page screenshots as base64 data
- **Isolated sessions** - `BrowserContext` with separate cookies/storage per context
- **Init scripts** - inject JavaScript before page scripts run

## Examples
...

### Projects using ChopChop
- https://github.com/dfkup/dfkup - A VM + JIT compiled scripting language written in Nim {planned as a `std/browser` package}

### ❤ Contributions & Support
- 🐛 Found a bug? [Create a new Issue](https://github.com/openpeeps/chopchop/issues)
- 👋 Wanna help? [Fork it!](https://github.com/openpeeps/chopchop/fork)

### 🎩 License
MIT license. [Made by Humans from OpenPeeps](https://github.com/openpeeps).<br>
Copyright OpenPeeps & Contributors &mdash; All rights reserved.
