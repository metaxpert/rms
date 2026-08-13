# Handoff — running the four apps against the live server

For a Flutter developer picking this up cold. The goal is to have all four apps signed in and
talking to the live backend, in realtime, in about fifteen minutes.

Read the two **Gotchas** at the bottom before you conclude anything is broken. Both are things
that look like app bugs and are not.

---

## 1. What you need

| | |
| --- | --- |
| **Flutter** | **3.44.9** (stable), Dart 3.12.2 |
| Device | An Android device or emulator. **Not Chrome** — see Gotcha 1. |
| Server | `https://rms.metaxperts.net/api` — already the built-in default. Nothing to configure. |
| Login | `chef@karahipoint.test` / `Password123!` |

The Flutter version is pinned in CI and `pubspec.lock` is committed. If you are on a different
version, use [fvm](https://fvm.app) rather than upgrading the lockfiles — `flutter pub get
--enforce-lockfile` is what CI runs, and a bumped lock will fail it.

## 2. Run it

```bash
git clone git@github.com:metaxpert/rms.git && cd rms

cd rms_waiter          # or rms_manager / rms_driver / rms_customer
flutter pub get
flutter run            # on an Android device or emulator
```

There is **no server address to type**. The production default is compiled in
(`packages/rms_core/lib/src/config/environment.dart`), so a plain `flutter run` already points at
the live backend. Sign in with the credentials above and pick a branch — **Karahi Point — Gulberg**
is the seeded one with data.

To point somewhere else — a staging box, or an API on your own laptop:

```bash
flutter run --dart-define=RMS_API_BASE=http://10.0.2.2:3300   # 10.0.2.2 = host, from an emulator
```

or at runtime, on the sign-in screen, under **Server settings**. Note that `RMS_API_BASE` must
include the `/api` prefix if the server is behind a reverse proxy that mounts it there — the live
one is.

## 3. Check your setup before blaming the app

If sign-in fails, confirm the backend is up and the credentials are good, independently of Flutter:

```bash
curl -s -X POST https://rms.metaxperts.net/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"chef@karahipoint.test","password":"Password123!"}'
```

A `200` with an `accessToken` means the server is fine and the problem is on the device. Access
tokens expire in **15 minutes** and the app refreshes them silently — if you are signed out mid-test,
that is a bug worth reporting, not expected behaviour.

## 4. What to test, per app

All four are live against real seeded data: a menu, a floor plan, orders, reservations.

| App | The path worth walking |
| --- | --- |
| **Waiter** | Floor → tap a table → build a ticket → **fire to kitchen** → bill → settle → receipt |
| **Manager** | The three tabs: live service, the kitchen board, settled sales |
| **Driver** | Runs board → pick up → share GPS → deliver with the customer's OTP |
| **Customer** | Browse the menu → basket → checkout → follow the order |

**Realtime is the interesting part.** Run the **waiter** and the **manager** side by side, on two
devices or a device and an emulator. Fire a ticket in the waiter app; it should appear on the
manager's kitchen board **without a refresh**. That is the Socket.IO gateway, and it is the thing
most worth confirming, because it was broken until the commit that added this document (see
Gotcha 2).

**The driver app's board starts empty**, because no delivery runs are seeded. To get one, place a
**DELIVERY**-channel order (customer app, or the web console): the backend opens the job as the order
is placed, and it appears on the runs board.

That last part is only true on a backend built after 2026-08-13. Before then nothing in the system
ever created a delivery job — `POST /restaurant/deliveries` existed with no caller anywhere — so a
delivery order cooked, reached `SERVED` when the kitchen bumped it, and stopped there. If you are
pointed at an older server, the board stays empty however many delivery orders you place, and that is
the bug rather than a seeding gap.

## 5. Known-not-built — please don't file these

These are deliberate, and documented with reasons in
[`rms_waiter/ARCHITECTURE.md`](../rms_waiter/ARCHITECTURE.md) §12:

- **Transfers and merges** of an order between tables — no backend endpoint exists.
- **Voiding a sent line, discounts, tips.** Sent lines are read-only by design.
- **Push notifications.** Local notifications only; they fire while the app's process is alive.
  Waking a killed app needs a device-token endpoint that does not exist yet.
- **Offline writes** beyond the single queued submission per table. There is no sync protocol
  server-side, so there is nothing honest to build.
- **Settling does not free the table.** No verified endpoint sets a table's status, so the app says
  the table frees up "once it has been cleared down" instead of claiming to have done it.
- The Urdu translation is **unreviewed by a native speaker**. `docs/urdu-proof-sheet.html` lists all
  388 strings for review, with 20 already flagged as suspect. Wrong Urdu is expected right now;
  see the sheet before reporting a string.

## 6. Before you push

```bash
bash scripts/check.sh          # analyze + tests + l10n drift, all five packages
```

This is exactly what CI runs (`.github/workflows/ci.yml`). Two things it catches that are easy to
trip over:

- **Localisations are generated *and* committed.** If you edit an `.arb`, run
  `flutter gen-l10n` and commit the regenerated `lib/src/l10n/`. Your local build rewrites it
  silently, so a stale file is invisible to you and lands as a mystery diff for someone else.
- **`flutter build web`** is in CI even though the apps are tested on Android. `flutter test` runs on
  the Dart VM and never compiles for the web, and dart2js rejects things the VM accepts.

Shared code lives in **`packages/rms_core`** — one API client, one session, one `Money`, one design
system, one sign-in journey. It exists because the four apps previously each carried their own copy
of the client and every copy was missing token refresh, so staff were signed out fifteen minutes
into a shift, four times over. **Fix a client bug there, not in an app.**

`dart format` is deliberately not enforced; the tree is not format-clean. Don't reformat files you
are touching for other reasons — it buries the actual change.

---

## Gotchas

### 1. `flutter run -d chrome` will fail. Use Android.

The API does not send an `Access-Control-Allow-Origin` header for a `localhost` origin, so a
browser blocks every call and sign-in fails with an opaque network error. The app is fine; CORS is
refusing it.

Verified:

```
$ curl -si -X OPTIONS https://rms.metaxperts.net/api/auth/login \
    -H 'Origin: http://localhost:8080' -H 'Access-Control-Request-Method: POST'
HTTP/2 204
access-control-allow-methods: GET,HEAD,PUT,PATCH,POST,DELETE
access-control-allow-headers: content-type,authorization
    ← no access-control-allow-origin
```

Test on Android. If you need the web build specifically, ask for your origin to be added to the
API's CORS allowlist — it is a one-line server change, not something to work around in the client.

### 2. Realtime: the gateway is under `/api/`, and this was a real bug

The Socket.IO gateway is served at **`/api/socket.io/`**, not `/socket.io/`. Behind this
deployment's nginx, `/` goes to the Next.js web console and only `/api/` reaches the NestJS API.

`Environment.socketBase()` used to *strip* the trailing `/api` before handing the URL to Socket.IO,
on the reasoning that the websocket namespace sits at the root. True of the API reached directly on
its own port — which is how it is reached in development — and false behind the production proxy,
where it aimed the socket at the web console's origin and `/socket.io/` returned Next.js HTML.

It **failed silently**, which is why it lasted: the socket is deliberately an accelerator and never
the source of truth, so every screen still refreshed on resume and on a slow poll. Nothing looked
broken. Realtime was simply never live.

Fixed: the origin and the path prefix are now split, because Socket.IO reads a path in its URL as a
*namespace* rather than a prefix, so the prefix has to travel as its `path` option instead.

```
https://rms.metaxperts.net/api  →  origin https://rms.metaxperts.net
                                   path   /api/socket.io/
```

Verified by connecting to the live gateway and getting `CONNECTED`. If realtime stops working, check
`socketIoTarget()` in `packages/rms_core/lib/src/realtime/realtime_client.dart` first — it has tests.

**A note on what to expect from realtime:** it is treated as an accelerator throughout, never a
source of truth. Screens also refresh on resume and on a slow poll, and `ORDER_VOIDED` is not
bridged at all. So "it eventually appeared" is working-as-designed; "it appeared without a refresh"
is what you are testing for.
