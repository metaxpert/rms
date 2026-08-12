# MetaXperts RMS — Restaurant Management System

An enterprise restaurant management system built as a **vertical module of the MetaXperts ERP**, plus a
suite of **native mobile apps**. It runs an entire restaurant end to end — take orders, fire the kitchen,
settle bills, dispatch deliveries, manage reservations — and closes the financial loop automatically:
every settled bill deducts inventory, captures real COGS, and posts a **balanced journal voucher** to the
general ledger. An AI service adds demand forecasting, prep-time prediction, and upsell recommendations.

> Demo tenant: **Karahi Point** · login `chef@karahipoint.test` / `Password123!`

---

## What's here

This repository is the **mobile + workspace** half of the RMS — the four Flutter apps, the demo seed, and
docs. The backend, web console, and AI service live in the MetaXperts ERP monorepo as the `restaurant`
vertical module.

```
rms/
├── rms_waiter/      Flutter — take & fire orders, settle
├── rms_manager/     Flutter — live dashboard (sales, kitchen, covers)
├── rms_driver/      Flutter — delivery runs: pickup, GPS, OTP
├── rms_customer/    Flutter — browse menu, order, track live
├── scripts/
│   └── seed-demo.sh one-command demo seed (Karahi Point)
└── docs/
    └── overview.html  a live system-overview dashboard
```

---

## Architecture

A modular monolith backend feeds a web console, four mobile apps, and a Python AI service — all sharing
one tenant-isolated Postgres database.

| Layer | Stack | Highlights |
| --- | --- | --- |
| **Backend** | NestJS · TypeScript · Postgres 16 | 25 RLS-protected tables · order→KDS→settle lifecycle · transactional outbox → RabbitMQ · recipe→inventory→COGS→GL · dynamic PRA/FBR fiscalization |
| **Web console** | Next.js · Tailwind · shadcn/ui | POS · menu/recipes/modifiers · floor designer · live KDS board · deliveries · reservations |
| **Mobile** | Flutter (this repo) | Waiter · Manager · Driver · Customer |
| **AI service** | Python · FastAPI | demand forecast · prep-time · upsell · service-token secured |

### The money loop closes itself

```
take order → fire to kitchen → settle (tender + PRA tax + rounding)
           → explode recipe → deduct valued inventory → capture weighted-avg COGS
           → outbox event → GL consumer → balanced journal voucher
```

Every stage is integer **minor-unit** money, tenant-scoped by Postgres RLS, and proven by an
end-to-end acceptance test.

---

## The four apps

All four are built on **`packages/rms_core`** — one API client, one session, one money
implementation, one design system, one sign-in journey. That package exists because the four apps
previously each shipped their own copy of a 125-line client, and every copy was missing token
refresh: staff were signed out fifteen minutes into a shift, four times over. Riverpod for state,
`http` over `dio`, and no photographs in the staff apps — all sized for the low-end Android devices
common in Pakistani restaurants.

Each app's server address is set on its sign-in screen (**Server settings**), or per build with
`--dart-define=RMS_API_BASE=…`.

| App | Flow |
| --- | --- |
| **Waiter** | Floor → tap a table → take order → fire to kitchen → bill → settle → print |
| **Manager** | Three views of one moment: service, kitchen board, settled sales |
| **Driver** | Runs board → pick up → share real GPS → deliver with the customer's OTP |
| **Customer** | Browse menu (photos) → basket → delivery/collection → follow it to the door |

Live updates come from the backend's Socket.IO gateway, with each app refreshing on resume and on a
slow poll as well — the bridge is best-effort and `ORDER_VOIDED` is not bridged at all, so the socket
is treated as an accelerator and never as the source of truth.

`rms_waiter/ARCHITECTURE.md` records what was verified against the running backend, what is still
unverified, and which gaps need a server-side answer (order transfers, a rider-scoped delivery list,
a customer-supplied delivery address).

### Run an app

```bash
cd rms_waiter        # or rms_manager / rms_driver / rms_customer
flutter pub get
flutter run          # a device/emulator, or: flutter run -d chrome
```

On the sign-in screen open **Server settings** and point it at your API
(e.g. `http://10.0.2.2:3399` for the Android emulator, or `http://localhost:3399` on the web).

---

## Documentation

| Doc | For |
| --- | --- |
| **[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)** | **Deploying to a real server** — production install, standalone vs. integrating with an existing ERP, first-run setup, running the restaurant, operations. Start here for a live deployment. |
| [docs/GUIDE.md](docs/GUIDE.md) | Developer / local setup — spin the whole thing up on your laptop to evaluate or hack on it. |
| [docs/overview.html](docs/overview.html) | Visual system-overview dashboard (open in a browser). |

---

## Quick start (with the ERP backend)

```bash
# 1. In the ERP repo: bring up infra + run migrations + start the API
docker compose -f infra/docker-compose.yml up -d
pnpm --filter @app/api migration:run
API_PORT=3399 WORKER_REACTIONS_ENABLED=1 OUTBOX_RELAY_ENABLED=1 pnpm --filter @app/api dev

# 2. Seed the demo restaurant (from this repo)
API_URL=http://127.0.0.1:3399 bash scripts/seed-demo.sh

# 3. Run any app (above), or the web console, pointed at :3399
```

The seed provisions the **Karahi Point** tenant, a chart of accounts + GL mapping, ingredients stocked in
grams, a photo menu, recipes, the floor plan, reservations, and a couple of live orders (one settled, so
revenue + COGS + a GL journal exist immediately).

---

## Acceptance test

The full path is covered by a repeatable end-to-end gate in the ERP repo
(`apps/api/test/restaurant-e2e.sh`, part of `pnpm --filter @app/api test:e2e`):

- setup → order → auto-fire KDS → **settle** (16% tax, weighted-avg **COGS**, stock deducted)
- **balanced GL journal** posts asynchronously (outbox → consumer)
- state-machine rejections (e.g. double-settle → 422)
- delivery lifecycle with **OTP** (wrong → 422, correct → delivered)
- reservation seating
- **RLS tenant isolation** (a second tenant gets 404 on the first's order)
- **printing**: station routing, agent claim, ESC/POS byte stream, receipt arithmetic, failure retry
- **scanning**: table QR issue/rotate, bill lookup, barcode scan-to-add
- **code generation**: internal EAN-13 minting (valid check digit, GS1 in-store range), QR/barcode
  images (SVG + PNG), printed labels with a native EAN-13 command
- **cross-module barcodes**: menu items and inventory products draw from one tenant-wide counter, so a
  scanned code can never resolve to the wrong catalogue; bulk minting and printable label sheets on both
- dynamic fiscal (PRA) configuration

`RESULT: 94 passed, 0 failed`.

---

## System overview dashboard

`docs/overview.html` is a self-contained, theme-aware dashboard visualising the whole system — the four
surfaces, the money loop with a real journal voucher, the AI models, and the 12-phase build with live
metrics. Open it in any browser.

---

## Build phases

Architecture-first, then services, UI, mobile, AI, and acceptance.

| # | Phase | | # | Phase |
| --- | --- | --- | --- | --- |
| 01 | Architecture & ADR | | 07 | Reservations |
| 02 | Schema · 25 RLS tables | | 08 | Web console |
| 03 | Menu & floor services | | 09 | 4 Flutter apps |
| 04 | Orders · KDS · realtime | | 10 | AI / ML service |
| 05 | Dynamic PRA/FBR fiscal | | 11 | Acceptance & E2E |
| 06 | Delivery + tracking | | 12 | Ops · seed & docs |

---

## Design principles

- **Multi-tenant, RLS-first** — every business query is tenant-scoped; Postgres RLS is the backstop.
- **Integer minor-unit money** — never floats; ISO-4217 currency; default PKR.
- **Transactional outbox** — events never leave a business write; idempotent consumers react.
- **Standalone-sell** — ship the ERP with only the `restaurant` feature entitled and it *is* an RMS.
- **Open-source deps only** — no paid/closed runtime dependencies.
