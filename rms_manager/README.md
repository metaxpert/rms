# RMS Manager

Three views of one moment in the service: what is happening, what the kitchen is
doing, and what has been taken.

Built on `packages/rms_core` — the same API client (with working token refresh),
session, money, theme and sign-in journey as the other three apps.

## The three tabs

| Tab | What it answers |
| --- | --- |
| **Service** | Is there anything I should get up for right now? |
| **Kitchen** | Where in the kitchen is the hold-up? |
| **Sales** | What has been closed, and what is still sitting on tables? |

They are fed by **one snapshot**, not one fetch per tab. Three tabs that
disagreed — 4 open bills here, 6 there — would be trusted by nobody, and
crossing between them costs nothing this way, which matters on a phone being
glanced at between two other jobs.

## Things worth knowing before changing it

**An outlet is a filter here, not a gate.** The waiter and driver apps cannot
function without one: a floor or a rider's board is meaningless tenant-wide, and
letting them through would silently show another outlet's data. Comparing
outlets is precisely a manager's job, so this app overrides
`authRequiresBranchProvider` to `false` in `main()` and puts the outlet in the
app bar. That is the only difference in the whole auth journey.

**Tiles are for things you can walk to.** Food going cold at the pass, a station
past its target, money on tables. A number nobody would get up about is not a
KPI, it is decoration — and a permanently coloured tile stops being noticed
within a shift, so the highlights only fire when there is something to do.

**"Settled", never "revenue".** Revenue is the ledger's word; recognition, tax
and rounding are decided in the GL, synchronously with the bill. What a phone can
honestly report is which bills were closed and for how much. The screen says so
at the bottom rather than implying it is a P&L.

**The kitchen board is read-only.** Chefs bump tickets from the KDS screen. A
manager bumping one from a phone would tell the pass that food was away when
nobody had plated it.

**Overdue is measured against the ticket's own target.** A ticket with no target
is never overdue — inventing a default would put half the board in red on a busy
night and teach everyone to ignore the colour.

**The read time is on screen.** Every figure comes from one fan-out fetch; a
dashboard that might be minutes stale and does not say so is worse than no
dashboard. The live-feed indicator says plainly when updates have stopped
arriving.

## Running it

```bash
flutter pub get
flutter run --dart-define=RMS_ENV=development
```

`RMS_ENV` is `development` | `staging` | `production` (default). The server
address can also be set per build with `--dart-define=RMS_API_BASE=…`, or in the
field from the sign-in screen's **Server settings**.

## Tests

```bash
flutter test
```

27 tests covering the derived figures (open vs settled vs cancelled, average
bill, currency), the kitchen board's grouping, ordering and overdue rule, and
the screens' promises above — including that the kitchen tab offers no way to
move a ticket.
