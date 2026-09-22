# Proposed Rule Examples

This document gives one invalid and one valid ReScript example for every rule
proposed in [RULE_CANDIDATES.md](RULE_CANDIDATES.md). A finding is an error when
its rule is enabled. Each invalid and valid half has been compiled independently
with ReScript 12.3.1. Shared values and functions are supplied by a typed fixture
module so each excerpt can stay focused on the rule.

JSX examples compile against `@rescript/react` 0.15.0 and its DOM prop spellings.
Test examples compile against `rescript-vitest` 3.0.1. Project examples were
also checked in the multi-file layouts described by their comments.

The reproducible audit is `node scripts/audit-rule-examples.mjs BINARY FIXTURE_PROJECT`.
The temporary project must already contain those pinned dependencies and a
`rescript.json` that compiles `src`. The runner regenerates the examples, compiles
them, creates real Reanalyze evidence, and checks both halves with only their
target rule enabled. The verified result is 198/198 passing examples with no
skips. Configured examples use nesting two, parameters three, function lines
five, nested suites two, and structural equality risk two. The project fixtures
include a real interface and a live consumer of the valid exported function.

## Syntax Rules

### `no-constant-condition`

```rescript
// Invalid
let label = if true {"ready"} else {"waiting"}

// Valid
let label = if isReady {"ready"} else {"waiting"}
```

### `no-constant-binary-expression`

```rescript
// Invalid
let canRun = true && false

// Valid
let canRun = isReady && isEnabled
```

### `no-duplicate-condition`

```rescript
// Invalid
let label = if status == #ready {
  "Ready"
} else if status == #ready {
  "Still ready"
} else {
  "Waiting"
}

// Valid
let label = if status == #ready {
  "Ready"
} else if status == #blocked {
  "Blocked"
} else {
  "Waiting"
}
```

### `no-identical-branches`

```rescript
// Invalid
let label = if isReady {"Ready"} else {"Ready"}

// Valid
let label = if isReady {"Ready"} else {"Waiting"}
```

### `simplify-boolean-expression`

```rescript
// Invalid
let visible = if isVisible {true} else {false}

// Valid
let visible = isVisible
```

### `no-useless-catch`

```rescript
// Invalid
let read = () => try {
  readConfig()
} catch {
| caught => throw(caught)
}

// Valid
let read = () => try {
  Some(readConfig())
} catch {
| Not_found => None
}
```

### `no-catch-all-exception`

```rescript
// Invalid
let read = () => try {
  Some(readConfig())
} catch {
| _ => None
}

// Valid
let read = () => try {
  Some(readConfig())
} catch {
| Not_found => None
}
```

### `no-empty-function`

```rescript
// Invalid
let handleClick = () => ()

// Valid
let handleClick = () => Analytics.track("button_clicked")
```

### `no-empty-file`

```rescript
// Invalid: Empty.res contains no declarations.

// Valid
let initialized = true
```

### `no-debugger`

```rescript
// Invalid
let inspect = value => {
  %debugger
  value
}

// Valid
let inspect = value => value
```

### `approx-constant`

```rescript
// Invalid
let circumference = radius => 2.0 *. 3.141592653589793 *. radius

// Valid
let circumference = radius => 2.0 *. Math.Constants.pi *. radius
```

### `no-useless-concat`

```rescript
// Invalid
let greeting = "Hello, " ++ "world"

// Valid
let greeting = "Hello, world"
```

### `no-warning-comments`

```rescript
// Invalid when TODO is configured as an error term:
// TODO: remove this fallback
let timeout = 1000

// Valid
// The fallback matches the legacy service timeout.
let timeout = 1000
```

### `max-nesting`

```rescript
// Invalid when the configured maximum is two.
let canPublish = user => {
  if user.active {
    if user.verified {
      if user.hasQuota {true} else {false}
    } else {false}
  } else {false}
}

// Valid
let canPublish = user => user.active && user.verified && user.hasQuota
```

### `max-params`

```rescript
type newUser = {id: int, name: string, email: string, role: string}

// Invalid when the configured maximum is three.
let createUser = (id, name, email, role) => {id, name, email, role}

// Valid
let createUser = input => input
```

### `max-lines-per-function`

```rescript
// Invalid when the configured maximum is five physical lines.
let prepareReport = data => {
  let normalized = normalize(data)
  let grouped = group(normalized)
  let sorted = sort(grouped)
  let summarized = summarize(sorted)
  render(summarized)
}

// Valid: the extracted functions are independently bounded.
let prepareReport = data => data->normalize->group->sort->summarize->render
```

## Typed and API-Aware Rules

### `no-self-compare`

```rescript
// Invalid
let version = currentVersion
let unchanged = version === version

// Valid
let unchanged = currentVersion === previousVersion
```

### `no-unintended-shallow-equality`

```rescript
// Invalid: these arrays should be compared by value.
let sameItems = currentItems === expectedItems

// Valid
let sameItems = currentItems == expectedItems
```

### `no-expensive-deep-equality`

```rescript
// Invalid when the configured structural risk threshold is two.
let unchanged = currentState == cachedState

// Valid
let unchanged = currentState.version === cachedState.version
```

### `no-float-equality`

```rescript
// Invalid
let closeEnough = measured == expected

// Valid
let closeEnough = Math.abs(measured -. expected) <= tolerance
```

### `prefer-pattern-check`

```rescript
// Invalid: comparing a payload-bearing list shape performs value comparison.
let isPair = (items: list<int>) => items == list{1, 2}

// Valid
let isPair = (items: list<int>) => switch items {
| list{1, 2} => true
| _ => false
}
```

### `prefer-empty-check`

```rescript
// Invalid
let empty = items->List.length == 0

// Valid
let empty = switch items {
| list{} => true
| list{_, ..._} => false
}
```

### `no-partial-function`

```rescript
// Invalid
let first = items->List.headOrThrow

// Valid
let first = items->List.head
```

### `no-dynamic-code`

```rescript
// Invalid
let calculate: string => int = %raw("code => eval(code)")

// Valid
let calculate = expression => Expression.evaluate(expression)
```

### `no-shared-array-initializer`

```rescript
type item = {mutable selected: bool}

// Invalid: every slot refers to the same mutable record.
let items = Array.make(~length=3, {selected: false})

// Valid
let items = Array.fromInitializer(~length=3, _ => {selected: false})
```

### `no-floating-promise`

```rescript
// Invalid: the promise is deliberately discarded.
let handleSave = user => {
  saveUser(user)->ignore
}

// Valid
let handleSave = async user => {
  await saveUser(user)
}
```

### `require-await`

```rescript
// Invalid
let loadCount = async () => 42

// Valid
let loadCount = async () => await fetchCount()
```

### `no-await-in-loop`

```rescript
// Invalid: Promise.resolve has no cross-iteration dependency.
let waitForAll = async () => {
  for _index in 0 to 3 {
    await Promise.resolve()
  }
}

// Valid
let waitForAll = async () => await [Promise.resolve(), Promise.resolve()]->Promise.all
```

### `only-used-in-recursion`

```rescript
// Invalid: config is only forwarded unchanged.
let rec contains = (items, config, wanted) => switch items {
| list{} => false
| list{head, ...tail} => head == wanted || contains(tail, config, wanted)
}

// Valid
let rec contains = (items, wanted) => switch items {
| list{} => false
| list{head, ...tail} => head == wanted || contains(tail, wanted)
}
```

### `eta-reduction`

```rescript
// Invalid when arity and attributes are provably equivalent.
let parse = text => Int.fromString(text)

// Valid
let parse = Int.fromString
```

### `no-ignored-result`

```rescript
// Invalid
let update = user => {
  validate(user)->ignore
  save(user)
}

// Valid
let update = user => switch validate(user) {
| Ok(validUser) => save(validUser)
| Error(error) => Error(error)
}
```

### `fuse-collection-pipeline`

```rescript
// Invalid: both callbacks are locally proven pure.
let transformed = values => values->Array.map(value => value + 1)->Array.map(value => value * 2)

// Valid
let transformed = values => values->Array.map(value => (value + 1) * 2)
```

### `no-accumulating-concat`

```rescript
// Invalid: each step allocates a new accumulated string.
let text = parts->Array.reduce("", (acc, part) => acc ++ part)

// Valid
let text = parts->Array.join("")
```

### `no-top-level-side-effect`

```rescript
// Invalid outside a configured entry module.
Console.log("module loaded")

// Valid
let initialize = () => Console.log("application started")
```

### `no-redundant-mutual-recursion`

```rescript
// Invalid: neither function calls the other.
let rec increment = value => value + 1
and double = value => value * 2

// Valid
let increment = value => value + 1
let double = value => value * 2
```

### `prefer-standard-combinator`

```rescript
// Invalid when this is proven equivalent to List.map.
let rec doubleAll = items => switch items {
| list{} => list{}
| list{head, ...tail} => list{head * 2, ...doubleAll(tail)}
}

// Valid
let doubleAll = items => items->List.map(value => value * 2)
```

## JSX Accessibility Rules

### `alt-text`

```rescript
// Invalid
let avatar = <img src="avatar.png" />

// Valid
let avatar = <img src="avatar.png" alt="Profile photo" />
```

### `anchor-ambiguous-text`

```rescript
// Invalid
let link = <a href="/billing"> {React.string("Click here")} </a>

// Valid
let link = <a href="/billing"> {React.string("View billing history")} </a>
```

### `anchor-has-content`

```rescript
// Invalid
let link = <a href="/docs" />

// Valid
let link = <a href="/docs"> {React.string("Documentation")} </a>
```

### `anchor-is-valid`

```rescript
// Invalid
let link = <a onClick={_ => openHelp()}> {React.string("Help")} </a>

// Valid
let link = <a href="/help"> {React.string("Help")} </a>
```

### `aria-activedescendant-has-tabindex`

```rescript
// Invalid
let listbox = <div role="listbox" ariaActivedescendant="item-1" />

// Valid
let listbox = <div role="listbox" ariaActivedescendant="item-1" tabIndex=0 />
```

### `aria-role`

```rescript
// Invalid
let control = <div role="clickable" />

// Valid
let control = <div role="button" />
```

### `aria-unsupported-elements`

```rescript
// Invalid
let metadata = <meta ariaHidden=true />

// Valid
let content = <div ariaHidden=true />
```

### `autocomplete-valid`

```rescript
// Invalid
let input = <input autoComplete="electronic-mail" />

// Valid
let input = <input autoComplete="email" />
```

### `click-events-have-key-events`

```rescript
// Invalid
let control = <div onClick={_ => submit()}> {React.string("Submit")} </div>

// Valid
let control = <button onClick={_ => submit()}> {React.string("Submit")} </button>
```

### `control-has-associated-label`

```rescript
// Invalid
let input = <input type_="search" />

// Valid
let input = <input type_="search" ariaLabel="Search" />
```

### `heading-has-content`

```rescript
// Invalid
let heading = <h2 />

// Valid
let heading = <h2> {React.string("Account settings")} </h2>
```

### `html-has-lang`

```rescript
// Invalid
let page = <html> <body /> </html>

// Valid
let page = <html lang="en"> <body /> </html>
```

### `iframe-has-title`

```rescript
// Invalid
let map = <iframe src="/map" />

// Valid
let map = <iframe src="/map" title="Office location" />
```

### `img-redundant-alt`

```rescript
// Invalid
let logo = <img src="logo.png" alt="Image of the company logo" />

// Valid
let logo = <img src="logo.png" alt="Acme" />
```

### `interactive-supports-focus`

```rescript
// Invalid
let control = <div role="button" onClick={_ => submit()} />

// Valid
let control = <div role="button" tabIndex=0 onClick={_ => submit()} />
```

### `label-has-associated-control`

```rescript
// Invalid
let field = <> <label> {React.string("Email")} </label> <input id="email" /> </>

// Valid
let field = <> <label htmlFor="email"> {React.string("Email")} </label> <input id="email" /> </>
```

### `lang`

```rescript
// Invalid
let quote = <blockquote lang="english" />

// Valid
let quote = <blockquote lang="en" />
```

### `media-has-caption`

```rescript
// Invalid
let video = <video src="demo.mp4" />

// Valid
let video = <video src="demo.mp4"> <track kind="captions" src="demo.vtt" /> </video>
```

### `mouse-events-have-key-events`

```rescript
// Invalid
let help = <div onMouseOver={_ => showHelp()} />

// Valid
let help = <div onMouseOver={_ => showHelp()} onFocus={_ => showHelp()} />
```

### `no-access-key`

```rescript
// Invalid
let save = <button accessKey="s"> {React.string("Save")} </button>

// Valid
let save = <button> {React.string("Save")} </button>
```

### `no-aria-hidden-on-focusable`

```rescript
// Invalid
let hidden = <button ariaHidden=true> {React.string("Hidden action")} </button>

// Valid
let visible = <button> {React.string("Visible action")} </button>
```

### `no-autofocus`

```rescript
// Invalid
let search = <input autoFocus=true />

// Valid
let search = <input />
```

### `no-distracting-elements`

```rescript
// Invalid
let notice = <marquee> {React.string("Important update")} </marquee>

// Valid
let notice = <p> {React.string("Important update")} </p>
```

### `no-interactive-element-to-noninteractive-role`

```rescript
// Invalid
let save = <button role="presentation"> {React.string("Save")} </button>

// Valid
let save = <button> {React.string("Save")} </button>
```

### `no-noninteractive-element-interactions`

```rescript
// Invalid
let save = <div onClick={_ => saveForm()}> {React.string("Save")} </div>

// Valid
let save = <button onClick={_ => saveForm()}> {React.string("Save")} </button>
```

### `no-noninteractive-element-to-interactive-role`

```rescript
// Invalid
let action = <li role="button"> {React.string("Remove")} </li>

// Valid
let action = <li> <button> {React.string("Remove")} </button> </li>
```

### `no-noninteractive-tabindex`

```rescript
// Invalid
let note = <div tabIndex=0> {React.string("Note")} </div>

// Valid
let action = <button> {React.string("Open note")} </button>
```

### `no-redundant-roles`

```rescript
// Invalid
let save = <button role="button"> {React.string("Save")} </button>

// Valid
let save = <button> {React.string("Save")} </button>
```

### `no-static-element-interactions`

```rescript
// Invalid
let menu = <span onClick={_ => openMenu()}> {React.string("Menu")} </span>

// Valid
let menu = <button onClick={_ => openMenu()}> {React.string("Menu")} </button>
```

### `prefer-tag-over-role`

```rescript
// Invalid
let save = <div role="button" tabIndex=0> {React.string("Save")} </div>

// Valid
let save = <button> {React.string("Save")} </button>
```

### `role-has-required-aria-props`

```rescript
// Invalid
let toggle = <div role="checkbox" tabIndex=0 />

// Valid
let toggle = <div role="checkbox" ariaChecked=#"true" tabIndex=0 />
```

### `role-supports-aria-props`

```rescript
// Invalid
let article = <article role="article" ariaChecked=#"true" />

// Valid
let toggle = <div role="checkbox" ariaChecked=#"true" tabIndex=0 />
```

### `scope`

```rescript
// Invalid
let cell = <td scope="col"> {React.string("Name")} </td>

// Valid
let heading = <th scope="col"> {React.string("Name")} </th>
```

### `tabindex-no-positive`

```rescript
// Invalid
let search = <input tabIndex=2 />

// Valid
let search = <input tabIndex=0 />
```

## React Rules

### `react/jsx-key`

```rescript
// Invalid
let rows = users->Array.map(user => <li> {React.string(user.name)} </li>)

// Valid
let rows = users->Array.map(user => <li key={user.id}> {React.string(user.name)} </li>)
```

### `react/no-array-index-key`

```rescript
// Invalid
let rows = users->Array.mapWithIndex((user, index) =>
  <li key={index->Int.toString}> {React.string(user.name)} </li>
)

// Valid
let rows = users->Array.map(user =>
  <li key={user.id}> {React.string(user.name)} </li>
)
```

### `react/no-children-prop`

```rescript
// Invalid
let panel = <Panel children={React.string("Settings")} />

// Valid
let panel = <Panel> {React.string("Settings")} </Panel>
```

### `react/no-danger-with-children`

```rescript
// Invalid
let content = <div dangerouslySetInnerHTML={{"__html": html}}>
  {React.string("Fallback")}
</div>

// Valid
let content = <div dangerouslySetInnerHTML={{"__html": html}} />
```

### `react/void-dom-elements-no-children`

```rescript
// Invalid
let image = <img src="logo.png"> {React.string("Acme")} </img>

// Valid
let image = <img src="logo.png" alt="Acme" />
```

### `react/button-has-type`

```rescript
// Invalid
let save = <button> {React.string("Save")} </button>

// Valid
let save = <button type_="button"> {React.string("Save")} </button>
```

### `react/jsx-no-target-blank`

```rescript
// Invalid
let docs = <a href=externalUrl target="_blank"> {React.string("Docs")} </a>

// Valid
let docs = <a href=externalUrl target="_blank" rel="noopener noreferrer">
  {React.string("Docs")}
</a>
```

### `react/iframe-missing-sandbox`

```rescript
// Invalid
let preview = <iframe src=previewUrl title="Preview" />

// Valid
let preview = <iframe src=previewUrl title="Preview" sandbox="allow-scripts" />
```

### `react/no-unstable-nested-components`

```rescript
// Invalid
@react.component
let make = () => {
  module Row = {
    @react.component
    let make = (~text) => <span> {React.string(text)} </span>
  }
  <Row text="Created during render" />
}

// Valid
module Row = {
  @react.component
  let make = (~text) => <span> {React.string(text)} </span>
}

@react.component
let make = () => <Row text="Stable component" />
```

### `react/jsx-no-constructed-context-values`

```rescript
type theme = {color: string}
module ThemeContext = {
  let context = React.createContext({color: "blue"})
  let make = React.Context.provider(context)
}

// Invalid: a new record is allocated on every render.
@react.component
let make = (~children) =>
  <ThemeContext value={{color: "blue"}}> children </ThemeContext>

// Valid
let defaultTheme = {color: "blue"}

@react.component
let make = (~children) =>
  <ThemeContext value=defaultTheme> children </ThemeContext>
```

### `react/exhaustive-deps`

```rescript
// Invalid: userId is captured but absent from the dependency array.
@react.component
let make = (~userId, ~loadUser) => {
  React.useEffect1(() => {
    loadUser(userId)
    None
  }, [])
  React.null
}

// Valid
@react.component
let make = (~userId, ~loadUser) => {
  React.useEffect2(() => {
    loadUser(userId)
    None
  }, (userId, loadUser))
  React.null
}
```

### `react/no-new-prop-value`

```rescript
// Invalid: both props are newly allocated during render.
@react.component
let make = () => <ItemList items={[1, 2, 3]} onSelect={item => select(item)} />

// Valid
let stableItems = [1, 2, 3]
let handleSelect = item => select(item)

@react.component
let make = () => <ItemList items=stableItems onSelect=handleSelect />
```

## Test-Framework Rules

### `test/no-focused-tests`

```rescript
open Vitest

// Invalid
test("saves the user", ~only=true, _ => saveUserTest())

// Valid
test("saves the user", _ => saveUserTest())
```

### `test/no-disabled-tests`

```rescript
open Vitest

// Invalid
test("saves the user", ~skip=true, _ => saveUserTest())

// Valid
test("saves the user", _ => saveUserTest())
```

### `test/no-identical-title`

```rescript
open Vitest

// Invalid
describe("user", () => {
  test("saves", _ => saveUserTest())
  test("saves", _ => saveAdminTest())
})

// Valid
describe("user", () => {
  test("saves a user", _ => saveUserTest())
  test("saves an admin", _ => saveAdminTest())
})
```

### `test/no-duplicate-hooks`

```rescript
open Vitest

// Invalid
beforeEach(resetDatabase)
beforeEach(resetClock)

// Valid
beforeEach(() => {
  resetDatabase()
  resetClock()
})
```

### `test/no-conditional-test`

```rescript
open Vitest

// Invalid: registration depends on runtime state.
if featureEnabled {
  test("uses the feature", _ => featureTest())
}

// Valid
test("uses the feature", t => {
  let result = runFeature(~enabled=featureEnabled)
  t->expect(result.enabled)->Expect.toBe(featureEnabled)
})
```

### `test/no-conditional-expect`

```rescript
open Vitest

// Invalid
test("shows the role", t => {
  if isAdmin {
    t->expect(label)->Expect.toBe("Administrator")
  }
})

// Valid
test("shows the role", t => {
  let expected = if isAdmin {"Administrator"} else {"Member"}
  t->expect(label)->Expect.toBe(expected)
})
```

### `test/prefer-hooks-in-order`

```rescript
open Vitest

// Invalid
afterEach(cleanup)
beforeEach(setup)

// Valid
beforeEach(setup)
afterEach(cleanup)
```

### `test/prefer-hooks-on-top`

```rescript
open Vitest

// Invalid
test("first test", _ => firstTest())
beforeEach(setup)

// Valid
beforeEach(setup)
test("first test", _ => firstTest())
```

### `test/require-top-level-describe`

```rescript
open Vitest

// Invalid
test("creates a user", _ => createUserTest())

// Valid
describe("user", () => {
  test("creates a user", _ => createUserTest())
})
```

### `test/valid-title`

```rescript
open Vitest

// Invalid
test("", _ => saveUserTest())

// Valid
test("saves the user", _ => saveUserTest())
```

### `test/expect-expect`

```rescript
open Vitest

// Invalid
test("saves the user", _ => saveUserTest())

// Valid
test("saves the user", t => {
  saveUserTest()
  t->expect(true)->Expect.toBe(true)
})
```

### `test/max-nested-describe`

```rescript
open Vitest

// Invalid when the configured maximum is two.
describe("user", () => {
  describe("admin", () => {
    describe("permissions", permissionsTests)
  })
})

// Valid
describe("admin permissions", () => {
  describe("write access", permissionsTests)
})
```

## Project Rules

### `no-restricted-modules`

```rescript
// Invalid in ui/Profile.res when UI-to-database access is forbidden.
let load = id => Database.User.find(id)

// Valid
let load = id => UserService.find(id)
```

### `no-unused-export`

```rescript
// Invalid in Metrics.res: no project consumer uses this public value.
let legacyCounter = () => 0

// Valid: remove the unused export or keep a value with a real consumer.
let recordRequest = request => MetricsStore.record(request)
```

### `no-deprecated-api`

```rescript
module Api = {
  let fetchUser = id => id

  @deprecated("Use fetchUser instead")
  let loadUser = id => fetchUser(id)
}

// Invalid
let fetch = id => Api.loadUser(id)

// Valid
let fetch = id => Api.fetchUser(id)
```

### `require-interface`

```rescript
// Invalid: Token.res exists without Token.resi.
type t = {value: string}
let make = (value: string): t => {value: value}

// Valid: Token.res is paired with Token.resi containing:
// type t
// let make: string => t
type t = {value: string}
let make = (value: string): t => {value: value}
```

### `require-license-header`

```rescript
// Invalid: the file begins directly with code.
let answer = 42

// Valid
// Copyright 2026 Example Authors
// SPDX-License-Identifier: MIT
let answer = 42
```

## Additional Policies

### `no-optional-some`

```rescript
let consume = (~value=?, ()) => value
// Invalid
let result = consume(~value=?Some(1), ())
// Valid
let result = consume(~value=1, ())
```

### `preferred-type-syntax`

```rescript
// Invalid
type values = Dict.t<int>
// Valid
type values = dict<int>
```

### `no-identity-operation`

```rescript
// Invalid
let calculate = (value: int) => value + 0
// Valid
let calculate = (value: int) => value
```

### `no-erasing-operation`

```rescript
// Invalid
let calculate = (value: int) => value * 0
// Valid
let calculate = (value: int) => value * 2
```

### `no-modulo-one`

```rescript
// Invalid
let calculate = (value: int) => value % 1
// Valid
let calculate = (value: int) => value % 2
```

### `no-obj-external`

```rescript
// Invalid
@obj external make: (~name: string) => {"name": string} = ""
// Valid
let make = (~name: string) => {"name": name}
```

### `no-mutable-record-field`

```rescript
// Invalid
type state = {mutable count: int}
// Valid
type state = {count: int}
```

### `no-record-mutation`

```rescript
type state = {mutable count: int}
// Invalid
let update = (state: state) => {state.count = 2}
// Valid
let update = (state: state) => {...state, count: 2}
```

### `no-while`

```rescript
// Invalid
let visit = (ready, work) => {while ready() {work()}}
// Valid
let visit = (values, work) => values->Array.forEach(work)
```

### `no-for`

```rescript
// Invalid
let visit = work => {for i in 0 to 2 {work(i)}}
// Valid
let visit = work => [0, 1, 2]->Array.forEach(work)
```

### `no-empty-loop`

```rescript
// Invalid
let wait = ready => {while ready() {()}}
// Valid
let wait = (ready, step) => {while ready() {step()}}
```

### `no-negated-condition`

```rescript
// Invalid
let choose = ready => if !ready {1} else {2}
// Valid
let choose = ready => if ready {2} else {1}
```

### `no-nested-ternary`

```rescript
// Invalid
let choose = (a, b) => a ? (b ? 1 : 2) : 3
// Valid
let choose = (a, b) => if a {if b {1} else {2}} else {3}
```

### `prefer-if`

```rescript
// Invalid
let choose = ready => switch ready {| true => 1 | false => 2}
// Valid
let choose = ready => if ready {1} else {2}
```

### `no-single-case-switch`

```rescript
// Invalid
let increment = value => switch value {| x => x + 1}
// Valid
let increment = value => value + 1
```

### `no-unnecessary-template`

```rescript
// Invalid
let greeting = `hello`
// Valid
let greeting = "hello"
```

### `max-lines`

The audit config uses `maxLines: 6`, including its shared prelude and comments.

```rescript
// Invalid
let one = 1
let two = 2
let three = 3
let four = 4
// Valid
let one = 1
```

### `max-switch-cases`

The audit config uses `maxSwitchCases: 2`.

```rescript
// Invalid
let classify = value => switch value {| 0 => "zero" | 1 => "one" | _ => "other"}
// Valid
let classify = value => switch value {| 0 => "zero" | _ => "other"}
```
