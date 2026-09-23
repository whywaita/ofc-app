# Web verification with vlmkit

`make verify-web` builds the Flutter web bundle and runs [vlmkit](https://github.com/mizchi/vlmkit)
against it. The gates are deterministic and key-free — no API key, no VLM judgement — and a
failing gate is a finding, not a flake to retry.

```bash
make verify-web-setup   # once: npm ci + Playwright's Chromium
make verify-web         # flutter build web --release, then vlmkit gates run
make verify-web-list    # the exact commands that would run, without starting anything
make serve-web-verify   # just the verification server, to poke at the app by hand
```

Web is the priority platform for this app, and the gates cover ground the Dart tests cannot:
touch-target size, focus order, what the accessibility tree actually exposes, and whether a
scripted journey through the seed dialog into the game screen still works.

## The problem this integration solves

Flutter paints the whole app into a canvas inside `<flt-glass-pane>`. The page DOM holds no
app content, so every DOM-geometry gate in vlmkit measures an empty page and returns a
**false clean**:

```
$ npx vlmkit check integrity https://whywaita.github.io/ofc-app/
verdict: CLEAN (0 fail, 0 warn, 0 exempted)
  1280x800: 4 component(s), ink 1.7%, 0 text block(s)   ← a screen full of text
```

`0 text block(s)` is the tell. A verification tool that says "clean" while measuring nothing is
worse than no tool, which is why this file exists rather than a one-line npm script.

vlmkit's documented answer for canvas UIs is to hand element rects in by hand
(`check integrity --elements elements.json --image frame.png`). That works, but it covers 6 of
the 18 integrity rules and needs a screenshot per state. Flutter can do better, because the
engine already owns a real accessibility DOM — roles, names, rects, `aria-disabled`, focus
handling — it just does not build it until something asks. Clicking the
`flt-semantics-placeholder` element the engine installs is that request. After it, the page
carries ordinary `<flt-semantics role="button" aria-label="…">` elements and the unmodified
DOM gates work.

## Why the server injects the click

`tools/vlmkit/serve-web.mjs` serves `app/build/web` and appends four lines to `index.html` that
click the placeholder on the first frame. It is not possible to make Playwright do it instead:

- The placeholder is a 1x1 element parked at `(-1, -1)`, so Playwright's own actionability
  checks (visible, stable, receives events) reject it. `vlmkit inspect interact --sequence`
  fails the step with `page.click: Timeout 5000ms exceeded`.
- No gate takes a pre-navigation script, and the gates that accept a script (`verify flow`,
  `inspect interact`) run their steps *after* navigation, which is too late to be the first
  thing that happens.

Injecting into the served copy is the smallest remaining hook, and it keeps the app untouched:
the deployed build never contains it, and no `--dart-define` had to be added to `main.dart`.
`--no-semantics` serves the same bundle without the bootstrap, which is how the false-clean
result above can be reproduced locally.

## What each gate can see

| Gate | Verdict on this app |
|---|---|
| `check integrity` | 8 text blocks at 3 viewports, geometry only (see rule settings below) |
| `check a11y touch` | Real tap-target sizes: 5 controls on the home screen, all ≥ 24×24 |
| `check a11y focus` | Nondeterministic against this app — measured and left out, see below |
| `scan handlers` | 45 handler registrations across 7 elements + globals, and which controls they belong to |
| `verify flow` | 8 steps: home → seed dialog → deal → disabled commit button → discard confirmation |

The flow is in `tools/vlmkit/flows/smoke.flow.json`. Two things about writing flows against this
DOM:

- Assertions are evaluated with `document.querySelector`, so `:has-text()` — which Playwright
  accepts in `click` — is **not** valid in an `expect`. Select by role and attribute instead
  (`flt-semantics[role="button"][aria-disabled="true"]`).
- Flutter animates between routes, and an assertion runs as soon as the previous action returns.
  A `wait` step is a route transition, not padding: without it the assertion reads the outgoing
  screen and the step fails on text that is still correct.

## What is out of reach

Being explicit about this matters more than the list of things that work, because a green gate
that cannot see a defect reads as a guarantee:

- **Anything painted.** The accessibility DOM is a *description* of the canvas, not a rendering
  of it: Flutter marks it `filter: opacity(0%)` and every text node computes to
  `rgba(0, 0, 0, 0)`. Colour, contrast and occlusion live in the Flutter theme and are not
  measurable from this DOM. Three integrity rules are therefore switched off in
  `vlmkit.gates.json`, each with a reason and an expiry, and they are the honest cost of the
  approach rather than a workaround — see `vlmkit gates suppressions`.
- **Drag and drop.** `verify flow` can click, hover, focus, press, type, fill and select; it
  cannot drag. Card placement in the game screen is drag-only, so the flow stops at "the initial
  five are dealt" and the played-out board is not reachable from a gate. `scan handlers
  --probe-drag` inventories drag surfaces without exercising placement.
- **Web Vitals.** `check perf` reports CLS correctly, but LCP/FCP measure the HTML shell (the
  loading spinner), not the Flutter app — a canvas is not an LCP candidate. The numbers are
  therefore not a statement about this app, and the gate is not in the list.
- **`check design`.** It judges role reuse across instances, and the home screen presents 2
  buttons and 1 heading — under its 3-instance floor it reports `nothing-judged`. Add it back
  when a screen has enough repeated components to say something.

## Known flake

`check a11y focus` was measured over ten consecutive standalone runs and is **not** in the gate
list. It failed 3 of 10, and neither outcome means what it says:

- Failing runs report `captured 5 focus step(s)` and one finding, `[trap] Focus stayed on the
  same element … across two Tab presses` (on the Practice button).
- Passing runs report `captured 1 focus step(s)` — the accessibility tree was not built yet, so
  the gate tabbed through a page with one focusable element and proved nothing.

Driving the same page with real `Tab` key events by hand gives a clean order — `OFCP` →
Standard → Deuces → Joker → Practice → Pass & Play → body — so the trap is the gate's tab
timing against Flutter's asynchronous semantics focus, not a defect in the app. The gate is
worth revisiting (a real focus trap is exactly the kind of bug this app should not ship), but a
gate whose pass means "measured nothing" and whose fail means "raced" belongs out of CI until
someone makes it deterministic:

```bash
npx vlmkit check a11y focus --wait-until load --timeout 30000 http://127.0.0.1:4173/
```

## Adding a gate

`vlmkit.gates.json` is the whole configuration: `webServer` starts the verification server,
`defaults.gates` is the list that runs for every page, and `defaults.rules` records every rule
that is switched off together with the reason and an expiry date. An expired suppression stops
being applied, so a stale entry fails the run rather than hiding quietly.
