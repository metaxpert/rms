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

---

## 6. Money

The backend posts a balanced GL journal from integer minor units. Verified against
the seeded demo bill: net `200000` + 16% tax `32000` = `232000` cash, COGS `40600`
against inventory `40600`, debits = credits = `272600`.

The app therefore uses `Money` (integer paisa) with:
- half-up rounding in exactly one place (`applyBp`), matching the server;
- symmetric rounding for negatives so a refund mirrors its charge;
- `split()` that distributes the remainder so split bills reconcile exactly.

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
   therefore last-write-wins. The app should refetch before mutating and surface
   server rejections rather than assume its cache is current. **Unverified**:
   whether order updates carry `updatedAt` usable for conflict detection — to
   confirm before building transfer/merge.
5. **Port drift** — the four apps default to `:3399`; this deployment serves the
   API at `/api` behind TLS. Default config must be corrected, not left to staff.

---

## 10. Decisions

| Decision | Rationale |
| --- | --- |
| **Riverpod** for state | Brief §3 asks for it; the existing apps use ad-hoc `setState` + a mutable singleton, which is not an architecture worth preserving. Adds little size. |
| Keep `http`, not `dio` | Existing pubspec comments cite low-end Tecno/Infinix devices; `http` is sufficient behind a repository layer. |
| `socket_io_client` | Required to speak the backend's actual realtime transport (§4). |
| Feature-first layout | Brief §4. |
| Integer `Money` | Brief §34/§35 and the GL contract (§6). |
| No secure-storage swap yet | `shared_preferences` is not encrypted. Flagged as a limitation; `flutter_secure_storage` is the intended upgrade for §29. |

---

## 11. Implementation plan

Phased, each phase validated with `flutter analyze` + `flutter test`.

| Phase | Scope | State |
| --- | --- | --- |
| 1 | Core: `Money`, typed errors, `Session`, `ApiClient` (refresh, retry, idempotency) | **Done, verified** |
| 2 | Riverpod wiring, design system, typed routing, env config, auth + branch selection | Next |
| 3 | Floor plan, tables, table detail | |
| 4 | Menu, search, modifiers, cart, draft persistence | |
| 5 | Order submission, KDS status, realtime client with reconnect | |
| 6 | Bill, settle, split, receipt printing, transfers | |
| 7 | Offline cache + sync queue, notifications, permissions | |
| 8 | Test suite (unit/widget/integration), accessibility, i18n scaffolding, hardening | |

## 12. Status

Phase 1 complete and verified: `flutter analyze` clean, 18 unit tests green
(`test/money_test.dart`) covering tax rounding against the real settled bill,
split-bill reconciliation across 4,000 generated cases, and parsing.

Everything beyond Phase 1 is **not yet built**. This document will be updated as
phases land rather than describing intent as if it were finished.
