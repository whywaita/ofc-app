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
list. It failed 3 of 10, and the outcomes split by whether Flutter had finished building the
accessibility tree when the gate started tabbing:

- 4 runs captured `1 focus step` — the tree was not up yet, so the page had a single focusable
  element and the gate passed having proved nothing.
- 6 runs captured 5-6 steps and split 3-3: three passed, three reported one finding,
  `[trap] Focus stayed on the same element … across two Tab presses` (on the Practice button).

So a pass means either "measured nothing" or "won the race", and a failure means "lost it" —
the same page state gives both verdicts about half the time.

Driving the same page with real `Tab` key events by hand gives a clean order — `OFCP` →
Standard → Deuces → Joker → Practice → Pass & Play → body — so the trap is the gate's tab
timing against Flutter's asynchronous semantics focus, not a defect in the app. The gate is
worth revisiting (a real focus trap is exactly the kind of bug this app should not ship), but a
gate whose pass can mean "measured nothing" belongs out of CI until someone makes it
deterministic:

```bash
npx vlmkit check a11y focus --wait-until load --timeout 30000 http://127.0.0.1:4173/
```

## Adding a gate

`vlmkit.gates.json` is the whole configuration: `webServer` starts the verification server,
`defaults.gates` is the list that runs for every page, and `defaults.rules` records every rule
that is switched off together with the reason and an expiry date. An expired suppression stops
being applied, so a stale entry fails the run rather than hiding quietly.

## Contrast: what the gates cannot see

`check integrity --rule check.integrity/low-contrast-text` is off for this app, and not because
the contrast is fine. It reads text colours from the DOM, and Flutter's accessibility DOM paints
nothing — every `<flt-semantics>` node is transparent, so the rule reports every label as 1.00:1.
Eight such findings appeared on the home screen, all false positives, and switching the rule off
left the app with no contrast coverage at all.

`tools/vlmkit/contrast-audit.mjs` measures the pixels instead: it screenshots the page, takes the
rect of every labelled node from the accessibility tree, then treats the most common colour inside
a rect as the background and the colour farthest from it as the text. Thresholds follow WCAG 2.1 —
4.5:1 for normal text, 3.0:1 for text at least 24px tall — and a disabled control is skipped
because 1.4.3 exempts inactive components.

```bash
make contrast-audit                        # home screen, 375x812
make contrast-audit CONTRAST_ARGS="--click Practice --click Start"   # then the dealt game screen
node tools/vlmkit/contrast-audit.mjs --json            # machine-readable
```

It fails the run on any label below its threshold, and `--allow "<label>;<reason>"` accepts one
explicitly, the same shape the vlmkit gates use. Two labels fail on the current build:
`Game Mode` (4.39:1) and the seed line (2.55:1, and it is also unlabelled in the accessibility
tree — see the seed finding in the PR). Both are invisible to every vlmkit gate.

Note the floor `check a11y touch` applies: WCAG AA 2.5.8 wants a 24px shorter side, so the three
32px mode buttons pass it. The 44px figure people quote is the iOS guideline, which this gate does
not enforce.

## A vision model on the same screens

The gates above are geometry and pixels; a vision model answers the questions geometry cannot —
"is anything cut off", "is there any hint how to drag a card". Any image-capable model works.
On OpenCode Go, 14 of the 33 served models were verified to accept image input — the probe sends
a real screenshot and asks for text that exists only in the image, so a wrong answer is visible:
`mimo-v2.6-pro`, `mimo-v2.6-flash`, `mimo-v2.5`, `qwen3.8-max`, `qwen3.8-flash`, `qwen3.7-plus`,
`qwen3.6-plus`, `minimax-m3`, `kimi-k2.7-code`, `glm-5.3-flash`, `omen-alpha`,
`deepseek-v4-flash-vision-exp`, `deepseek-flash`, `deepseek-v4.1-flash`. Four more returned
nothing or denied seeing an image at all (`deepseek-v4-pro`, `kimi-k2.6`, `kimi-k3`, `longcat-2.0`),
the `glm-5.1/5.2/5.3` chat models reject images outright ("This model does not support image
inputs"), and `grok-4.6/4.7`, `gpt-5.6-luna`, `minimax-m2.7` were answering 503 from upstream
when this was written.

A first attempt at this probe is worth recording as a mistake: the test image was a blank white
page (the data: URL had not painted before the screenshot), so every "I see no text" reply looked
like a model that could not see — while in fact it was a correct reading of a white image. Check
that the test image has content before trusting a negative result.

Feed the model a screenshot and a question with a verifiable answer — that is what makes the reply
trustworthy: asked for the cards in each row, three models returned the same three rows the
accessibility tree reported, and asked about a 568px-tall capture all of them reported the
Action Log cut off after `draw: 5`.

`tools/vlmkit/vision-review.mjs` runs that loop: it drives the page with Playwright, screenshots
a screen, sends it to a vision model and prints the reply (optionally to `--out <dir>` as a
screenshot plus a markdown report). It needs `OPENCODE_GO_API_KEY` in the environment and exits 2
without it, so it never runs in CI — the key is never read from or written to a file.

```bash
make vision-review                                          # home screen
make vision-review VISION_ARGS="--click Practice --click Start"   # the dealt game screen
```

## How the two layers combine

Neither layer is the answer on its own. The deterministic side — the vlmkit gates plus
`contrast-audit.mjs` — proves things about geometry, colour and state, but it only looks where it
is pointed and it cannot describe what a screen means. The vision model reads meaning off the
pixels but will confidently describe a rendering it has misread. Used as hypothesis and proof,
in that order, they cover each other:

| Defect | Found by the vision model | Confirmed by the deterministic side |
| --- | --- | --- |
| Action Log unreachable at 375x568 | "content appears to continue past the bottom edge" | 35 of 52 labelled rects fall outside the viewport; `docScrollHeight == innerHeight` |
| Seed line unreadable | "light gray text, lower contrast than adjacent text" | measured 2.55:1 against a 4.5:1 floor |
| No way to know a card must be dragged | "no visible hint how to use the row controls" | the cards are `Draggable` with no `flt-tappable` node and no keyboard path |

And in the other direction, two replies from the same run that the deterministic side disproves —
do not file these:

- **"Next 3 is gray on gray, low contrast."** It is a *disabled* control (the tray still holds a
  card), and WCAG 1.4.3 exempts inactive components; `contrast-audit.mjs` reports it as skipped
  rather than failing.
- **"The seed input looks active while Random is selected."** In Random mode the input carries
  `disabled` — the field is inert, and typing into it does nothing. The vision model read a
  disabled field as an active one.

Both come from the same blind spot: a single screenshot cannot distinguish "painted this way" from
"painted this way *because* the control is disabled". Any reply that is about state rather than
appearance has to be re-checked against the accessibility tree before it becomes a finding.
