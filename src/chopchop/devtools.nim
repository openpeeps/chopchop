## Low-level Chrome DevTools Protocol (CDP) wrapper, reimplemented natively in
## chopchop. Transport is handled by powpow's WebSocket client and wire JSON
## by openparser/json (typed params/results).
##
## Ref: https://chromedevtools.github.io/devtools-protocol/1-3/

import devtools/core/[chrome, base, browser],
       devtools/domains/[target, page, runtime, network, dom, input, fetch,
                         emulation, browser_domain]
export chrome, base, browser,
       target, page, runtime, network, dom, input, fetch, emulation,
       browser_domain