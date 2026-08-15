# Macro DSL for chopchop

A compile-time AST-rewriting macro that provides a declarative scripting syntax on top of chopchop's existing high-level API. No runtime DSL types — the macro directly transforms DSL statements into `Page`/`Locator`/`ElementHandle` calls at compile time.

---

## Vision

```nim
newScript "A description of the script":
  goto "https://example.com"
  click "h1.fw-bold"
  if x == x:
    goto "https://"

  withForm "form#contact-form":
    fill "input[name='name']", "George Lemon"
```

---

## Approach

- **No runtime `Script` type** — the macro is purely a compile-time transformation
- **Page binding** — supports both implicit capture (`page` from enclosing scope) and explicit parameter `newScript(page, "desc")`
- **Scope management** — `withForm` pushes/pops a CSS scope prefix entirely at compile time (AST transform)
- **Control flow preservation** — `if`/`for`/`while`/`case`/`block` bodies are recursively transformed; conditions left as-is
- **Non-DSL code** — `let`, `var`, constant expressions, and unrecognized calls pass through unchanged

---

## Transformation Table

| DSL | Generated code |
|---|---|
| `goto "https://..."` | `await page.goto("https://...")` |
| `click "h1"` | `await page.locator("h1").click()` |
| `dblclick "h1"` | `await page.locator("h1").dblclick()` |
| `hover "h1"` | `await page.locator("h1").hover()` |
| `fill "input", "text"` | `await page.locator("input").fill("text")` |
| `typeText "input", "text"` | `await page.locator("input").typeText("text")` |
| `press "Enter"` | `await page.press("Enter")` |
| `press "button", "Enter"` | `await page.locator("button").press("Enter")` |
| `selectOption "sel", "val"` | `await page.locator("sel").selectOption("val")` |
| `selectOptionByLabel "sel", "label"` | `await page.locator("sel").selectOptionByLabel("label")` |
| `selectOptionByIndex "sel", 0` | `await page.locator("sel").selectOptionByIndex(0)` |
| `textContent "h1"` | `await page.locator("h1").innerText()` |
| `innerHTML "div"` | `await page.locator("div").innerHTML()` |
| `getAttribute "a", "href"` | `await page.locator("a").getAttribute("href")` |
| `isVisible "h1"` | `await page.locator("h1").isVisible()` |
| `waitForSelector "h1"` | `await page.waitForSelector("h1")` |
| `waitForNavigation` | `await page.waitForNavigation()` |
| `screenshot` | `await page.screenshot()` |
| `evaluate "1+1"` | `await page.evaluate("1+1")` |
| `count "selector"` | `await page.locator("selector").count()` |
| `withForm "form": <body>` | Push `"form"` to selector scope, recurse body, pop scope (compile-time) |
| `if/for/while/block: <body>` | Preserved, bodies recursively transformed |

---

## Implementation

**File:** `src/chopchop/dsl.nim`

### Macro overloads

```nim
macro newScript*(desc: string; body: untyped): untyped =
  ## Implicit page binding — captures `page` via bindSym("page")

macro newScript*(page: Page; desc: string; body: untyped): untyped =
  ## Explicit page binding
```

### Core AST walker

```nim
proc transformDSL(node: NimNode; scope: var seq[string]; page: NimNode): NimNode
```

Pattern-matches:
- `nnkCall` with known command name → rewrite to `page.<cmd>(...)` or `page.locator(<scope_sel>).<action>(...)`
- `nnkCall` named `withForm` → save scope, set new scope, recurse body, restore scope (via try/finally)
- `nnkIfStmt` / `nnkForStmt` / `nnkWhileStmt` / `nnkBlockStmt` → recurse into body nodes
- `nnkElifBranch` / `nnkOfBranch` / `nnkExceptBranch` → recurse into body
- `nnkCall` with known page-level commands (no selector needed) → `await page.<cmd>(<args>)`
- All other nodes → return unchanged

### Command classification

**Page-level** (no locator, no selector scope):
`goto`, `press` (1-arg), `waitForNavigation`, `screenshot`, `evaluate`, `waitForSelector`

**Locator-based** (use selector, apply scope prefix):
`click`, `dblclick`, `hover`, `fill`, `typeText`, `press` (2-arg), `selectOption*`, `setInputFiles`, `textContent` → `innerText`, `innerHTML`, `getAttribute`, `isVisible`, `count`

---

## Example output

Input:
```nim
newScript "Fill contact form":
  goto "https://example.com/contact"
  withForm "#contact-form":
    fill "input#name", "Alice"
    fill "input#email", "alice@example.com"
    click "button[type='submit']"
```

Compiles to:
```nim
block:
  echo "[Script] Fill contact form"
  await page.goto("https://example.com/contact")
  block:
    await page.locator("#contact-form input#name").fill("Alice")
    await page.locator("#contact-form input#email").fill("alice@example.com")
    await page.locator("#contact-form button[type='submit']").click()
```

---

## Status

- [ ] `dsl.nim` — `newScript` macro + `transformDSL` AST walker
- [ ] Command mapping table (all locator and page-level commands)
- [ ] Scoped selector prefix (compile-time stack)
- [ ] Control flow recursion (if/for/while/block/case)
- [ ] `withForm` with try/finally scope management
- [ ] Overloaded page binding (implicit + explicit)
- [ ] Error reporting (unknown commands, missing page)
- [ ] Examples using the DSL
