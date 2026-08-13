# UI/UX audit — the four RMS apps

Audit of the four Flutter apps as they stood before this pass, what was changed, and what was
deliberately left. Read alongside [DESIGN.md](DESIGN.md), which documents the system this pass
built.

## Where the codebase already was

This was not a codebase that needed rescuing, and the work was scoped accordingly. Before this
pass it already had design tokens (`AppSpacing`, `AppRadius`, `AppSizes`, `AppStatusColors`),
shared loading/empty/error surfaces, composed screen-reader labels on every card, a documented
reason for a 56dp touch target instead of Material's 48, a floor plan that falls back to a grid
when the designer's canvas would render untappable tables, and Urdu proven end to end including
right-to-left layout.

So this was not a case of applying a theme to something unstyled. The gaps were narrower and
sharper: a status palette defined only for light surfaces, no type scale at all, spinners where
skeletons belonged, no motion, four apps that looked identical, and a handful of layouts that
break at text sizes the apps themselves claim to honour.

---

## Priorities

### P0 — can cause a mistake or an operational failure

**1. The status palette had no dark mode, and the correction ran backwards.** ✅ Fixed

`AppStatusColors` defined ten fixed colours tuned for a light surface — `settled` is `#424242`,
`served` is `#37474F`. Every badge, border, ticket card and table card in all four apps painted
them unchanged on dark surfaces, so a settled badge rendered as dark grey text inside a dark grey
pill. Worse, the `textOn()` helper *darkened* colours to reach AA on white, which on a dark surface
is exactly the wrong direction and made the worst cases worse.

Fixed by giving every status a dark counterpart at the same hue, and splitting resolution into
`context.statusFill()` (fills, borders, icons — 3:1) and `context.statusText()` (small text —
4.5:1). `StatusBadge` resolves automatically, which fixed most call sites in one edit.

**2. `seated` failed WCAG AA as badge text in light mode.** ✅ Fixed

Measured at **4.488:1** against the badge's blended background. Found by the new contrast test, not
by a person. Remapped to `#0D47A1` (6.74:1). The other nine statuses had margin; the whole set is
now asserted on every build, in both brightnesses.

**3. Layouts broke at text sizes the apps declare they support.** ✅ Fixed

Four separate overflows, each found by rendering real screens at real device sizes rather than by
reading code:

| Where | Symptom | Cause |
| --- | --- | --- |
| Driver run screen | 81px off the right at 1.5x | `Row` with no `Flexible` around the status sentence |
| Customer cart line | Line rendered 1394px tall | Icon buttons grew with text scale and starved the name to zero width |
| Customer cart line | 15px off the right at 2x | `Rs 2,202.84` alone is 331px at 2x — wider than a 360px phone |
| Customer totals | Clipped at 2x | `Row(spaceBetween)` with two unflexed `Text`s |

Fixed respectively with `Flexible`; a bounded `_QtyStepper` built as one control; stacking the name
above the total past 1.4x; and flexing the label while never shrinking the figure.

### P1 — significantly reduces usability

**4. Every wait was a bare centred spinner.** ✅ Fixed

Nine screens showed a `CircularProgressIndicator` where the shape of the content was already known.
A spinner looks identical whether a request is in flight or the wifi died thirty seconds ago.
Skeletons now cover the waiter's floor and bill, the manager's three tabs, the driver's board, and
the customer's menu and order tracker. One shader per group, not per box.

**5. Nothing moved.** ✅ Fixed

No animation anywhere beyond Material's defaults. Status changes snapped. Added purposeful motion
only where a change matters — a table turning "ready", a rider clocking on, an order tracker
advancing, the basket bar arriving — with reduced-motion honoured throughout. See DESIGN.md §6.

**6. There was no typography system.** ✅ Fixed

All four apps used Material's default `textTheme` untouched, with hierarchy improvised per call
site via `copyWith(fontWeight: w700)` in roughly ninety places. Replaced with an explicit 13-step
scale, weights running heavier and line height more generous than Material for the reading
conditions this product is used in.

**7. All four apps looked identical.** ✅ Fixed

Same seed, same theme, nothing to tell them apart on a shelf of charging tablets. Four flavours
now, differing *only* in primary hue — asserted by a test that the rest of the system stays shared.

**8. The manager's KPI grid was hard-coded to two columns.** ✅ Fixed

Two is right on a phone and wrong on the 10" tablet by the till, where it produced two playing-card
tiles with dead space down both sides. Fixed — twice. The first attempt capped the column count,
which is the same bug wearing a hat: four columns of a 1194px tablet is four 280px tiles. The
correct lever is the tile extent. The helper that encouraged the mistake was removed rather than
left in the design system.

**9. Dish photos jumped, and "loading" looked like "no photo".** ✅ Fixed

The customer menu's `loadingBuilder` showed the same crossed-plate placeholder used for a *failed*
image, then popped to the photo in one frame. A guest on a slow connection saw a screen of
crossed-out plates and concluded the restaurant had no pictures. Now: a plain tinted well while
loading, the plate only on genuine failure, a fade-in on arrival, and no animation at all when the
image was already cached.

### P2 — consistency and polish

**10. Four copies of the same section header.** ✅ Fixed — one `SectionHeader`.

**11. Adding to the basket gave feedback or not, depending on where the thumb landed.** ✅ Fixed

Tapping the dish row announced it; tapping the `+` beside it added silently. Both now confirm
identically.

**12. Two form fields overrode the themed input decoration.** ✅ Fixed

The customer's menu search and delivery-address fields set their own `OutlineInputBorder`, so the
two fields a guest actually types in looked unlike every other field in the product.

**13. The manager dashboard used a fill colour for 12px label text** where the floor screen
correctly used the darkened variant — an inconsistency in the very rule the codebase documents.
✅ Fixed by routing both through `MetricTile`.

**14. Four hand-built confirmation dialogs** with independently-chosen button order and no visual
distinction for destructive actions. ✅ Fixed — one `confirmAction()`, destructive actions in the
error colour.

**15. Five hand-rolled inline banners.** ✅ Fixed — one `AppNotice` with four tones.

**16. Sign-in had no autofill.** ✅ Fixed — `AutofillGroup` plus username/password hints, so a
password manager can fill and commit both fields.

**17. A selected chip's label failed AA — introduced by this pass, and caught by it.** ✅ Fixed

Setting the chip theme's `labelStyle` to the shared `labelLarge` gave it `onSurface`, which is
correct on a surface and wrong on the `secondaryContainer` a *selected* chip fills with:
**3.69–4.28:1** across all four flavours in both brightnesses. Found by rendering the customer menu
and looking at it, then confirmed by measurement. The label colour now resolves per state, and the
assertion is in the test suite.

### P3 — deliberately not done

- **A tablet grid for the customer menu.** Built, then removed. A `GridView` row is a fixed height
  and a dish tile is not; pinning one to the other clipped the price at large text sizes. Replaced
  with a width-capped centred list, which solves the actual tablet problem (rows stretching to
  1194px) without the fragility. This is §32 of the brief in practice — the grid was the fancier
  answer and the worse one.
- **A bundled brand typeface.** Would mean adding binary font assets and a licence decision that is
  the client's to make. The scale is defined in a way that a family swap is a one-line change.
- **Illustrated empty states.** The brief warns against meaningless illustrations; the tinted-glyph
  treatment carries the same weight without commissioning artwork.

---

## Per-app notes

### Waiter — optimised for speed during service

The strongest app before this pass and the least changed. Floor plan, spatial-memory layout,
draft/pending-send indicators, and the settle flow were all left alone functionally.

Changed: table cards resolve status colours for brightness and animate the transition to "ready";
the floor and bill wait behind skeletons shaped like themselves; both pinned action bars are lifted
off the content they cover; the local section header and both confirmation dialogs moved to the
shared components; the menu picker's search box became the shared field, which is now identical to
the guest's.

Not changed: every business rule. Sending, settling, idempotency, the draft/sent separation, and
the permission gate are untouched.

### Manager — optimised for scanning

Changed: the KPI grid re-flows by tile extent; the two call-to-action banners and all six KPI tiles
use shared components; the kitchen board's urgency colour and elapsed-time figure resolve for
brightness; the station headers and sales section headers use `SectionHeader`; all three tabs have
tab-shaped skeletons.

Not changed: the kitchen board stays read-only. A manager bumping a ticket from a phone would tell
the pass that food was away when nobody had plated it.

### Driver — optimised for speed and safety

Changed: the board waits behind a skeleton; the duty bar animates its state change and resolves its
colours; "something went wrong" now uses the shared destructive confirmation; the terminal-state
bar no longer runs off the side of a small phone at 1.5x.

Not changed: one large action, the OTP the app never shows or stores, and the aggregator case that
offers no buttons because it would be a lie.

### Customer — optimised to sell

The most changed app, and the one with the most room. Changed: dish tiles restructured for a
food-first hierarchy with the price on its own line in the brand colour; photo handling reworked;
shared search field; basket bar animates in; cart lines restructured into two rows with a bounded
stepper; totals and the place-order button hold up at 2x; the order tracker's steps are joined by a
rail and animate as the order advances; skeletons on the menu and the tracker.

Not changed: the checkout state machine, the idempotency keys, and the "the restaurant re-prices
every line" note.

---

## What is still open

1. **The two `l10n` bookkeeping failures in `scripts/check.sh`** are not code faults. The check
   regenerates the localisations and asserts git sees no diff; the driver's generated files (from
   the previous session's work) and the customer's (from the `clearSearch` key added here) are
   correct but uncommitted. Both clear on commit.
2. **No golden/screenshot tests.** The responsive suites assert that nothing throws and nothing
   overflows across device sizes, brightnesses and text scales, which catches structural breakage.
   They do not catch a colour or a spacing regression that still lays out cleanly.
3. **Dark mode has not been reviewed on a real device.** It is correct by construction, held by
   contrast tests in both brightnesses, and was inspected as rendered images during this pass —
   which is how the chip regression above was found. But nobody has looked at it on a real tablet
   in a real dining room, and the render harness has no fonts loaded, so it shows layout and colour
   rather than type. That is worth an hour before it ships.
4. **Screens not touched by this pass**: branch selection, the server settings sheet, the receipt
   sheet, and the waiter's item-options sheet. They inherit the new theme, typography and component
   styling, but none had its layout reviewed.
5. **`AppMotion.fast` and `AppElevation.raised`/`sheet` are defined but lightly used.** They are
   referenced by the theme rather than by screens. Worth revisiting if they are still unused after
   the next feature.

---

## Validation

Everything below is `bash scripts/check.sh --build`, which is what CI runs.

| | Result |
| --- | --- |
| `flutter analyze` × 5 packages | Clean, no warnings or infos |
| `flutter test` × 5 packages | All pass — **480 tests** (core 165, waiter 166, manager 45, driver 47, customer 57), of which **63 are new** |
| `flutter build web --release` × 4 apps | All succeed |
| l10n parity (en/ur, both directions) | Passes; one key added to the customer catalogue, translated |
| WCAG AA contrast | Asserted for all 10 statuses × 2 brightnesses, plus body copy |
| Overflow across devices | Asserted at 4 sizes × 2 brightnesses × text scale ceilings |

New test files:

- `packages/rms_core/test/design_system_test.dart` (19) — the system's own guarantees: contrast in
  both brightnesses, hue stability, type scale monotonicity, flavour distinctness, touch-target
  floors, reduced motion, breakpoints.
- `rms_manager/test/responsive_test.dart` (15) — the dashboard and both other tabs across four
  device sizes and both brightnesses.
- `rms_customer/test/responsive_test.dart` (17) — menu and basket to the 2x ceiling.
- `rms_driver/test/responsive_test.dart` (12) — a run across four statuses and the 1.0–1.5x range.

Between them these found six defects that code review had not: the `seated` contrast miss, the four
overflows listed under P0.3, and the selected-chip regression this pass introduced.

### One thing to know about the starting point

The working tree did not compile when this pass began. A rename of `OrderStatus.preparing` to
`OrderStatus.inProgress` had been applied to the enum declaration but not to the switch arms in the
same file, nor to five call sites and eight test fixtures. `flutter analyze` failed in `rms_core`
and `rms_waiter`, and nothing could be tested or built.

Completing that rename was a precondition for any of this work, so it was finished first, as its
own change: three switch arms, `order_detail.dart`, `order_progress.dart`, and the fixtures that
still sent `PREPARING` as an order status — which the API does not send, since `PREPARING` is a KDS
*ticket* status. It is unrelated to the UI pass and should be reviewed as its own commit.
