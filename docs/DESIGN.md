# The design system

One product, four jobs. This is what the four apps share, why they share it, and where each one is
allowed to differ.

Everything here lives in `packages/rms_core/lib/src/theme/app_theme.dart` and
`packages/rms_core/lib/src/widgets/`. Nothing styling-related belongs in a screen: if a value is
needed twice, it belongs in a token.

The guarantees below are held by `packages/rms_core/test/design_system_test.dart`, plus a
per-app `responsive_test.dart` that renders real screens at real device sizes in both
brightnesses. Those tests are the reason this document can make claims rather than intentions.

---

## 1. What differs between the apps, and what does not

Exactly one thing differs: the primary hue.

| App | Seed | Why |
| --- | --- | --- |
| Waiter | `#00695C` teal | The service floor, and the product's original palette |
| Manager | `#4A3B8C` violet-indigo | Analytical, and distinct from the driver's blue on a shelf of charging tablets |
| Driver | `#00629E` azure | The most legible of the four outdoors, which is where it is read |
| Customer | `#A32638` crimson | The only one a guest sees, and the only one that has to look like somewhere you would eat |

Spacing, radii, type scale, touch targets, status palette, and every shared component are
identical across all four. A member of staff who moves between two of these apps is re-learning
nothing. The hue is doing one honest job: telling someone which of four apps is open on a device
pile at the start of a shift.

`AppTheme.light()` with no argument still means the waiter's teal, so nothing that predates
`AppFlavor` changed behaviour.

A flavour's primary is never a status colour — asserted in the test suite — because primary is
chrome and status lives in badges.

---

## 2. Colour

### Semantic status palette

Ten statuses, each with a light-surface identity and a dark-surface counterpart:

| Status | Light | Dark |
| --- | --- | --- |
| `available` | `#2E7D32` | `#7CC47F` |
| `seated` | `#1565C0` | `#8FC1F5` |
| `ordering` | `#6A1B9A` | `#CB92DC` |
| `preparing` | `#E65100` | `#FFA95C` |
| `ready` | `#00838F` | `#52C7D6` |
| `served` | `#37474F` | `#AEBCC4` |
| `billRequested` | `#AD1457` | `#F08FB2` |
| `settled` | `#424242` | `#BFBFBF` |
| `cancelled` | `#B71C1C` | `#EF9A9A` |
| `reserved` | `#795548` | `#C0AAA1` |

Same hue in both, so a waiter who has learned that cyan means "food up" does not re-learn it when
the tablet flips to dark at dusk. Only the tone changes.

### The two resolvers, and why you must use them

The domain layer returns a status's **identity** — `OrderStatus.color`, `TableStatus.color`,
`DeliveryStatus.color`. That value is defined for a light surface and must never be painted
directly.

```dart
context.statusFill(status.color)   // fills, borders, icons  — needs 3:1
context.statusText(status.color)   // labels and small text  — needs 4.5:1
```

The correction runs in **opposite directions** by brightness. On a light surface several fills are
too light to read at 12px and are darkened; on a dark surface they are too dark, and the lifted
dark-mode tone is what reads. A single context-free table applied the light-mode darkening
everywhere, which made the worst case worse.

Four statuses are darkened for light-mode small text: `ready`, `preparing`, `available`, and
`seated`. The last of those was measured at **4.49:1** — a hair under WCAG AA — and was found by
the contrast test, not by a person.

`StatusBadge` resolves both automatically, so most screens never call these directly.

### Colour is never the only signal

Every status surface pairs colour with a label, and with an icon wherever one exists. Roughly one
man in twelve has some form of colour-vision deficiency and restaurant staff are not screened for
it.

---

## 3. Typography

An explicit scale, replacing Material's defaults. The defaults left hierarchy to be improvised at
each call site, which is how a codebase ends up with `titleMedium.copyWith(fontWeight: w700)` in
ninety places and no two headings quite alike.

| Style | Size | Line | Weight | Used for |
| --- | --- | --- | --- | --- |
| `displaySmall` | 36 | 1.15 | 700 | A single hero figure |
| `headlineLarge` | 30 | 1.20 | 700 | |
| `headlineMedium` | 26 | 1.23 | 700 | KPI values |
| `headlineSmall` | 22 | 1.27 | 700 | Screen headlines |
| `titleLarge` | 20 | 1.30 | 600 | App bar titles |
| `titleMedium` | 17 | 1.35 | 600 | Card titles, dish names |
| `titleSmall` | 15 | 1.35 | 600 | Row titles |
| `bodyLarge` | 16 | 1.45 | 400 | Running text |
| `bodyMedium` | 14 | 1.45 | 400 | Default body |
| `bodySmall` | 13 | 1.40 | 400 | Metadata, muted |
| `labelLarge` | 15 | 1.30 | 600 | Buttons |
| `labelMedium` | 13 | 1.30 | 600 | Chips, section headers |
| `labelSmall` | 11 | 1.30 | 600 | Never load-bearing |

Three deliberate departures from Material, all for the same reason — this is read at arm's length,
in motion, in bad light:

- **Weights run heavier.** Titles are 600 where Material says 500.
- **Small text is bigger.** `labelMedium` and `bodySmall` are 13 rather than 12.
- **Line height is generous.** 1.4–1.5 on body copy, because Urdu ascenders and descenders collide
  at Material's tighter defaults and the same screen has to hold both scripts.

Sizes only ever go **up** from Material's, never down. The contrast suite's "large text"
relaxation is a size boundary, so shrinking a style is a contrast regression waiting to be found by
a person rather than a test.

---

## 4. Spacing, radius, size

```
AppSpacing   xs 4   sm 8   md 12   lg 16   xl 24   xxl 32
AppRadius    sm 8   md 12  lg 16   pill 999
AppSizes     minTouchTarget 56    primaryActionHeight 64
             tableCardMin 150     menuItemMin 168
```

56, not Material's 48. Staff moving quickly mis-tap at 48, and a mis-tap here means a wrong dish or
a double charge. Primary actions ("Send to kitchen", "Settle", "Picked up") are 64 and sit away
from destructive controls.

---

## 5. Elevation

Material 3 prefers tonal surfaces to drop shadows, and a floor tablet viewed at an angle in dim
light reads a border more reliably than a shadow. Cards are therefore flat with a tonal fill and a
hairline border.

`AppElevation.lift(brightness)` is the one exception: a single soft shadow for surfaces pinned
*over* a scrolling list — the settle bar, the ticket action bar — so the content scrolling
underneath reads as passing behind the bar rather than ending at it. It is brightness-aware,
because the black shadow that lifts a white card is invisible on a dark one.

---

## 6. Motion

```
AppMotion.fast   120ms   a colour or opacity change on something already on screen
AppMotion.normal 200ms   the default: a card appearing, a section expanding
AppMotion.slow   320ms   a whole-screen change of state
```

Curves: `enter` (decelerating), `exit`, `standard`.

Restaurant software is used against a queue. Nothing runs longer than a third of a second.

**Reduced motion is honoured, not noted.** `AppMotion.of(context)` returns `Duration.zero` when the
platform asks for it; `SkeletonGroup` stops shimmering and `FadeIn` becomes a no-op. Vestibular
disorders are not rare, and a member of staff cannot opt out of the app they were handed at the
start of a shift.

Where motion is used, and why:

| Where | What | Why |
| --- | --- | --- |
| Table card | Fill and border animate | A table turning "ready" is the one change a waiter must catch |
| Duty bar | Colour animates | Clocking on changes what the rest of the screen means |
| Order tracker | Step markers animate | The one screen a guest sits and watches |
| Basket bar | Slides up | A bar that appears instantly is a bar pressed by accident |
| Dish photos | Fade in over their well | Cached images skip it entirely |
| Empty/error views | Fade and lift once | Reads as the answer landing, not a flicker |

---

## 7. Components

In `packages/rms_core/lib/src/widgets/`. Nothing was extracted for being used twice — each is
something a user is meant to *recognise* across screens, where the recognition is the feature.

| Component | Replaces | Notes |
| --- | --- | --- |
| `SectionHeader` | Four near-identical local copies | Uppercase, tracked; loses to the content under it |
| `MetricTile` | The manager's `_Kpi` | Value scales down rather than clipping |
| `AppNotice` | Five hand-rolled inline banners | Four tones, or an explicit status accent |
| `AppSearchField` | Two search boxes, one without a clear button | |
| `StatusBadge` | — | Resolves its own colours for the surface |
| `LoadingView` | — | Takes a `skeleton:` in the shape of the content |
| `EmptyView` / `ErrorView` | — | Width-capped, tinted glyph, fade in |
| `Skeleton` family | Bare spinners | One shader for the whole group |
| `FadeIn` | — | 8px lift, once, on first build |
| `confirmAction()` | Four hand-built `AlertDialog`s | Fixed button order; `isDestructive` paints the error colour |

### Skeletons

The sweep is drawn once at the `SkeletonGroup`, not per box. A screen of twenty tiles runs one
animation, not twenty — and the highlight crosses the layout as a single band instead of every tile
pulsing on its own clock.

A skeleton must be shaped like what is coming. One whose proportions are invented produces exactly
the visible jump it was meant to prevent.

### Confirmation dialogs

Safe choice on the left as a text button, committing choice on the right as a filled button,
`isDestructive` in the error colour. Staff build muscle memory for dialogs faster than for anything
else on screen, and a dialog that swaps its buttons round is how a round gets cleared by accident.

---

## 8. Responsiveness

Breakpoints follow Material's window size classes, so a decision here matches what the platform
does at the same width: compact `<600`, medium `<840`, expanded `>=840`.

**Grids re-flow by capping the tile, never the column count.** A column cap looks like the same
thing and is the same bug wearing a hat: capping the manager's KPI grid at four columns on a
1194-pixel tablet does not give you more tiles, it gives you 280-pixel ones. Hand Flutter a
`SliverGridDelegateWithMaxCrossAxisExtent` and cap the extent. There is deliberately no
`columns(minExtent:, max:)` helper in `AppBreakpoints` — it was written, it encouraged the bug, and
it was removed.

**Fixed row heights and variable-height content do not mix.** A `GridView` row is a fixed height; a
dish tile is not. Pinning one to the other clips content the moment a guest turns their text size
up. Where content varies, use a list and cap its width instead.

### Text scaling, per app

| App | Range | Why |
| --- | --- | --- |
| Waiter, Manager | 0.9–1.3 | Shared tablets; past 1.3 the floor grid and KPI tiles reflow far enough to truncate |
| Driver | 1.0–1.5 | Read outdoors, at arm's length, in motion — the floor is raised, not lowered |
| Customer | 0.9–2.0 | Their own phone, their own settings, and nobody to ask |

The ceilings are where layouts break, so they are where the tests run.

---

## 9. Accessibility

- Every interactive target is at least 56dp.
- Status is never carried by colour alone.
- All contrast is held to WCAG AA — including the badge label against its *blended* background,
  which is what the label actually sits on.
- Cards that read as one thing announce as one thing: `Semantics(container: true)` with a composed
  label, so a screen reader says "Table D1, Seated, seats 4, order Ready Rs 1,531.00, food ready,
  unsent ticket" rather than eight disconnected fragments.
- Anything that cannot be operated is not announced as a button — a merged table, for instance.
- Reduced motion is honoured.
- Icon-only controls carry a tooltip, which is what a screen reader reads.

---

## 10. Rules of thumb

**Clarity > Consistency > Speed > Accessibility > Beauty.**

- Never paint `status.color` directly. Resolve it.
- Prefer a skeleton to a spinner wherever the shape of the content is known.
- A snackbar is for something that stops being true. Anything that stays true is stated in place,
  and stays — that is what `AppNotice` is for.
- Do not put every piece of information in a card.
- A figure a user is deciding on — a price, a total, a KPI — scales down. It never ellipsises.
- If a grid needs a fixed row height to work, it should probably be a list.
