# Waiter App — System Inspection & Implementation Plan

Findings from inspecting the MetaXperts ERP backend (`apps/api`, branch
`feat/restaurant-vertical`) and the existing Flutter apps, before writing feature
code. Everything below was verified against the running deployment or the source,
not assumed. Where something is **unverified**, it says so.

---

## 1. Backend inspection

| Question | Finding |
| --- | --- |
| Backend technology | NestJS · TypeScript · Postgres 16 (pgvector image) · RabbitMQ · Redis · MinIO |
| API architecture | **REST**. No GraphQL. Responses wrapped in `{ "data": ... }`; errors are RFC 7807 `application/problem+json` |
| Realtime | **Socket.IO** gateway (`modules/realtime`) — see §4 |
| Auth | JWT access token + **rotating, single-use** refresh token — see §3 |
| Database | Postgres, multi-tenant, **row-level security**; apps connect via PgBouncer as a non-superuser so RLS always applies |
| Money | **Integer minor units** (paisa). Never floats — see §6 |
| Idempotency | Supported natively — see §5 |
| Offline support | **None server-side.** No sync protocol, no conflict resolution, no vector clocks. See §8 |
| API documentation | None found (no OpenAPI/Swagger artifact). Contracts inferred from controllers + verified live |
| Existing frontends | Next.js web console; four Flutter apps (waiter/manager/driver/customer) |
| Existing tests | Backend: unit + `restaurant-e2e` (94 checks). Flutter apps: default stub `widget_test.dart` only |

### Restaurant module

`apps/api/src/modules/restaurant` — one controller, `@Controller('restaurant')`,
with services split by concern: `menu`, `floor`, `order`, `kds`, `recipe`,
`delivery`, `reservation`, `scan`, `printing`, `fiscal`, plus
`restaurant-gl.consumer` which posts the accounting.

Route groups (verified): `areas`, `branches`, `categories`, `config`,
`gl-config`, `fiscal-config`, `items` (+`/recipe`, `/modifier-groups`),
`modifier-groups`, `modifiers`, `orders` (+`/items`, `/receipt`), `recipes`,
`reservations`, `tables`, `printers`, `print-jobs`, `deliveries` (+`/trail`),
`kds/board`, `kds/tickets/:id/kot`, `codes/qr`, `codes/barcode`.

---

## 2. Order lifecycle

Statuses found in the restaurant module:

```
DRAFT → PLACED → CONFIRMED → PREPARING → READY → SERVED → SETTLED
                                                      ↘ CANCELLED / VOID
```

**These are the backend's names and the app must map them verbatim** — no invented
client-side status vocabulary (brief §13). Transitions are enforced server-side;
the e2e suite asserts rejections such as double-settle → 422. The client should
*disable* invalid actions for UX, but must treat the server as the authority.

---

## 3. Authentication

```
POST /auth/login    { email, password }
  → { accessToken, refreshToken, tokenType: "Bearer", expiresIn: "15m" }
POST /auth/refresh  { refreshToken }  → same shape, NEW refreshToken
POST /auth/logout
POST /auth/2fa/verify
```

**Verified live, and this is the single most important integration detail:**

- Access tokens last **15 minutes**.
- Refresh tokens **rotate**. After a refresh, the old refresh token returns **401**
  — confirmed by replaying one.

Consequences the client must honour:

1. **Refresh must be single-flight.** If two requests each notice an expiring
   token and both POST `/auth/refresh`, the first consumes the token and the
   second gets 401 → the waiter is signed out mid-service. `ApiClient._refresh`
   memoises the in-flight future so concurrent callers share one refresh.
2. **The rotated token must be persisted before anything else proceeds**, or a
   crash between refresh and save loses the session permanently.
3. **A network failure during refresh must not sign the user out** — the token is
   probably still valid once wifi returns.

> The existing app (`lib/src/api.dart`, pre-rewrite) does **not** implement refresh
> at all: it stores only `accessToken` and throws "Session expired" on any 401.
> **Sessions therefore die after 15 minutes of service.** This is the most serious
> defect in the current waiter app and is fixed in the new core.

JWT claims carry `sub`, `tenantId`, `roles`, `perms` — decodable client-side for
UI gating only. Verification is the server's job.

---

## 4. Realtime

Socket.IO gateway, tenant-scoped:

- Handshake must carry a valid **access JWT** via `auth.token`, `?token=`, or a
  Bearer header; unauthenticated sockets are disconnected immediately.
- On success the socket joins room `tenant:<tenantId>` and receives
  `ready { tenantId }`.
- **All domain events arrive on a single channel named `event`**, shaped
  `{ type, payload }` — not one Socket.IO event name per domain event.

Bridged restaurant events (verified complete list):

```
restaurant.order_placed.v1        restaurant.bill_settled.v1
restaurant.order_confirmed.v1     restaurant.delivery_assigned.v1
restaurant.kds_ticket_ready.v1    restaurant.delivery_completed.v1
restaurant.order_served.v1        restaurant.reservation_created.v1
```

`restaurant.kds_ticket_ready.v1` is the kitchen→waiter signal the brief's §13
asks for, so the "kitchen marks food READY → waiter is told" flow is genuinely
supported without polling.

### ⚠ Gap found

**`RESTAURANT_ORDER_VOIDED` is defined in `EVENT_TYPES` but is NOT in
`BRIDGED_TYPES`.** A void performed by a manager or another till will therefore
**not** reach waiter tablets in realtime. The app must reconcile voids by
refetching (on resume, on table open, and on a slow background poll) and must not
present its cached order state as authoritative. Fixing this properly means adding
the event to the bridge server-side — out of scope for the app, worth raising.

Delivery of the bridge is **best-effort**: it subscribes on exclusive,
auto-deleted queues, and the code comments state a broker outage degrades
silently. Realtime is therefore an *accelerator*, never the source of truth.
Every screen must still be correct if the socket never connects.

### What the client does about it (Phase 5)

`RealtimeClient` (in `rms_core`) speaks the gateway; `LiveSync` decides what to
refresh. Three details are worth stating because each fixes a specific failure:

1. **The handshake token is fetched per attempt, not captured once.** Access
   tokens last 15 minutes; a socket reconnecting an hour into a shift with its
   original JWT would be dropped forever. The library's `authFn` hook runs on
   every `onopen`, and it calls `ApiClient.freshAccessToken` — routing through
   the same single-flight refresh the request path uses, so a reconnect during a
   refresh cannot consume the rotating refresh token twice.
2. **Reconnection is the library's**, with its jittered backoff, because a
   dining room of tablets returning after a wifi drop must not retry in lockstep.
3. **The socket is closed on sign-out.** The room is tenant-scoped, so holding
   it open would deliver the next user's events to the previous user's screens.

Because the room is tenant- rather than branch-scoped, a multi-outlet tenant
delivers every outlet's traffic to every tablet; `RealtimeEvent.isForeignTo`
filters it, but only on a payload that names a *different* branch — payload keys
are unverified, and discarding an event we could not classify would silently
stop the floor updating.

`LiveSync` also refreshes on **app resume** and on a **60-second poll**, since
neither the socket nor a resume covers the unbridged `ORDER_VOIDED` above. The
poll only costs requests when a screen is actually watching, because both
refreshed providers are `autoDispose`.

---

## 5. Idempotency — supported

`IdempotencyInterceptor` is registered globally (`APP_INTERCEPTOR`).

- Header: **`idempotency-key`** on unsafe methods, and a tenant must be in context.
- First request claims the key; on success its response is stored.
- A duplicate **replays** the stored response with header `Idempotency-Replayed: true`.
- Same key + **different body** → **422**.
- Same key **still in flight** → **409**.

The 409 case matters operationally: if "settle" times out on a weak connection and
the client retries with the same key while the original is still running, the
retry gets 409. Surfacing that would tell a waiter the bill failed while it was in
fact succeeding. `ApiClient` therefore treats **409-with-an-idempotency-key as
retryable**, backs off, and collects the replayed response.

### Who owns the key (Phase 5)

`ApiClient` mints a key per call, which covers *its own* transport retries. That
is not enough for anything a human retries: a waiter tapping "Send" again after a
timeout would claim a fresh key and open a **second bill for the table**. Every
mutation therefore accepts a caller-supplied key, and the send flow persists one
(`PendingSendStore`) that survives the process. Because the interceptor rejects a
key replayed with a *different* body, the submission also freezes its item
payload — a resume re-sends byte-identical items, and the ticket is locked
against edits until it resolves.

---

## 6. Money

The backend posts a balanced GL journal from integer minor units. Verified against
the seeded demo bill: net `200000` + 16% tax `32000` = `232000` cash, COGS `40600`
against inventory `40600`, debits = credits = `272600`.

The app therefore uses `Money` (integer paisa) with:
- `taxAt()` — **truncating**, because `computeMenuLine` does
  `Math.floor(taxable × bp / 10000)`. This is the method every priced line uses;
- `applyBp()` — half-up, which matches the server only where it rounds a bill
  (`Math.round`), not where it taxes a line. The two disagree on an exact half,
  and a ticket that disagrees with the printed bill by a paisa is a ticket a
  waiter stops trusting;
- `roundedToNearest(100)` — rupee rounding that follows JavaScript's half-toward-+∞
  `Math.round`, not Dart's half-away-from-zero `round()`;
- symmetric rounding for negatives so a refund mirrors its charge;
- `split()` that distributes the remainder so split bills reconcile exactly.

The draft ticket's arithmetic (`TicketDraft`) mirrors `computeMenuLine` and
`recomputeTotals` line for line, and is tested against fixtures generated by
running the backend's own formulas in Node — so a divergence fails in CI rather
than at a table.

Currency and tax rate are **read from `/restaurant/config`** (`currency`,
`defaultTaxBp`), never hard-coded — the brief's §35 requirement. `PKR`/1600 are
this tenant's values, not constants.

---

## 7. Permissions

Restaurant permissions found:

```
restaurant:operate            restaurant:kds:operate
restaurant:order:write        restaurant:print
restaurant:menu:write         restaurant:config:write
restaurant:floor:write        restaurant:delivery:dispatch
```

The JWT carries `perms`. The app gates UI affordances on these, but — per brief
§21 — the client is **never** the authorization boundary; the server re-checks.

---

## 8. Offline — what is and is not true

**The backend has no offline sync protocol.** There is no merge, no conflict
resolution, no client-generated ID reconciliation. So the app must not claim
transactional offline capability (brief §15).

What is honestly achievable:

| Safe offline | Requires the server |
| --- | --- |
| Read cached menu, categories, tables, areas, config | Placing an order |
| Compose/edit a **draft** ticket locally, persisted | Firing to kitchen |
| View last-known order state (clearly marked stale) | Settling a bill |
| Queue a *single* pending submission with an idempotency key | Any state transition |

Idempotency keys make a queued submission safe to retry, which is the one genuine
offline win available. Everything else is read-cache plus honest UI state. Drafts
must never be silently discarded.

---

## 9. Architectural risks identified

1. **Refresh-token rotation + concurrency** — the classic way to sign users out
   mid-service. Mitigated by single-flight refresh (§3).
2. **`ORDER_VOIDED` not bridged** — stale order state after a remote void (§4).
3. **Realtime is best-effort** — must never be the only path to correctness.
4. **No optimistic-concurrency token observed** on restaurant orders (no `version`
   / `If-Match` seen). Concurrent edits from another till or the web POS are
   therefore last-write-wins. Mitigated in Phase 5 as far as the API allows: the
   send flow refetches the table's order immediately before mutating, and a
   rejection is surfaced with what the server said rather than swallowed. It is
   a narrower race, not a closed one. **Unverified**: whether order updates carry
   `updatedAt` usable for conflict detection — to confirm before building
   transfer/merge.
5. **Port drift** — the four apps default to `:3399`; this deployment serves the
   API at `/api` behind TLS. Default config must be corrected, not left to staff.
6. **Modifier groups are invisible from the item list.** `GET /restaurant/items`
   omits them entirely, so nothing but a per-item `GET /restaurant/items/:id`
   reveals that a dish needs configuring — and that detail returns the groups'
   *rules* without their *choices*, which cost a further `GET
   /restaurant/modifier-groups/:id` each (the list endpoint returns only a
   count). Mitigated by fetching the tenant's groups once per session and
   caching item details; when a tenant defines no groups at all — as the demo
   seed does — the picker skips the detail call entirely and adds on one tap.
   A `hasModifiers` flag (or embedded groups) on the list endpoint would remove
   the round trips; worth raising server-side.
7. **Modifier selection rules are not enforced server-side.** `addItems`
   validates that each modifier exists and is available, but never checks a
   group's `required` / `minSelect` / `maxSelect`. The client is therefore the
   only thing stopping an under-specified line reaching the kitchen — which is
   exactly the situation brief §21 warns about, so it is called out here rather
   than relied upon quietly.

---

## 10. Decisions

| Decision | Rationale |
| --- | --- |
| **Riverpod** for state | Brief §3 asks for it; the existing apps use ad-hoc `setState` + a mutable singleton, which is not an architecture worth preserving. Adds little size. |
| Keep `http`, not `dio` | Existing pubspec comments cite low-end Tecno/Infinix devices; `http` is sufficient behind a repository layer. |
| `socket_io_client` | Required to speak the backend's actual realtime transport (§4). |
| Feature-first layout | Brief §4. |
| Integer `Money` | Brief §34/§35 and the GL contract (§6). |
| Tokens in the platform keystore | Landed in Phase 1: `flutter_secure_storage` holds the access/refresh tokens, with a one-time migration off the plaintext `shared_preferences` copy earlier builds wrote. Non-secrets (server address, branch, remembered email, ticket drafts) stay in preferences. |
| Menu search filters locally | The API supports `?q=`, but a waiter types with a guest waiting: filtering an already-loaded catalogue answers each keystroke instantly and survives a wifi blackspot. A restaurant menu is hundreds of rows. |
| No photographs in the waiter's menu | The customer app sells with pictures; a waiter is scanning for a name they already know, and a photo per tile would slow the grid on the same wifi the order has to travel over. |

---

## 11. Implementation plan

Phased, each phase validated with `flutter analyze` + `flutter test`.

| Phase | Scope | State |
| --- | --- | --- |
| 1 | Core: `Money`, typed errors, `Session`, `ApiClient` (refresh, retry, idempotency) | **Done, verified** |
| 2 | Riverpod wiring, design system, typed routing, env config, auth + branch selection | **Done, verified** |
| 3 | Floor plan, tables, table detail | **Done, verified** |
| 4 | Menu, search, modifiers, cart, draft persistence | **Done, verified** |
| 5 | Order submission, KDS status, realtime client with reconnect | **Done, verified** |
| 6 | Bill, settle, split, receipt printing, transfers | Next |
| 7 | Offline cache + sync queue, notifications, permissions | |
| 8 | Test suite (unit/widget/integration), accessibility, i18n scaffolding, hardening | |

### Sending a round (Phase 5)

Submission is four server calls — `create`, `items`, `place`, `confirm` — on a
device that can be killed between any two of them. The failure to design against
is not a failed request; it is **one round billed twice**. Three things prevent
it:

- **A persisted per-step idempotency key**, so a retry replays rather than
  repeats (§5).
- **A recorded stage**, so a retry continues from where it stopped instead of
  starting over.
- **Adopting any open bill the table already has** before creating one. This
  covers the window where the order was created but its id was never written
  down, and it is also what makes a second round append to the bill rather than
  open a rival one.

`confirm` is skipped when the order is already CONFIRMED, because a tenant with
`autoFireKitchen` fires during `place` — reporting that as a failure would send
a waiter to the pass to chase food already being cooked. If the bill is settled
or voided elsewhere mid-send, the round is kept on the tablet and the waiter is
told plainly; nothing is silently re-billed.

Success is declared only after the bill has been read back, so the moment the
progress panel clears the screen already shows what the server holds.

## 12. Status

**Phases 1–5 complete and verified.** `flutter analyze` clean across `rms_core`
and `rms_waiter`, 88 + 120 tests green, `flutter build web --release` succeeds.

What a waiter can do today: sign in, choose an outlet, read the floor from the
designer's own table coordinates, open a table, browse and search the menu,
configure a dish's options, build a ticket that predicts the bill to the paisa,
and **send it to the kitchen** — with the table's existing bill and the unsent
round shown separately so it is never ambiguous which the kitchen has. The floor
and an open ticket update live off the Socket.IO gateway, and a "food is ready"
ticket raises an alert wherever the waiter is.

What is **not** built: settling. No bill is closed, split, tipped or printed;
the order stops at CONFIRMED and whatever the kitchen does to it afterwards.
Sent lines are read-only — voiding one is a manager's action and belongs with
the rest of Phase 6.

Known rough edge, stated rather than hidden: a round is locked against edits
while a submission is outstanding, because the frozen payload is what makes a
resume safe. A waiter who wants to change it must stop the send first.

This document is updated as phases land rather than describing intent as if it
were finished.
