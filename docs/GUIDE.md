# MetaXperts RMS — Complete Setup & Operations Guide

A step-by-step walkthrough: bring up the backend, seed the demo restaurant, run the web console, the four
mobile apps, and the AI service, then run the acceptance gate. Every command is copy-pasteable.

- [1. Prerequisites](#1-prerequisites)
- [2. Bring up the backend](#2-bring-up-the-backend)
- [3. Seed the demo restaurant](#3-seed-the-demo-restaurant)
- [4. Run the web console](#4-run-the-web-console)
- [5. Run the mobile apps](#5-run-the-mobile-apps)
- [6. Run the AI service](#6-run-the-ai-service)
- [7. The money loop, explained](#7-the-money-loop-explained)
- [8. Acceptance / E2E test](#8-acceptance--e2e-test)
- [9. Troubleshooting](#9-troubleshooting)

---

## 1. Prerequisites

| Tool | Version | For |
| --- | --- | --- |
| Docker + Compose | latest | Postgres, PgBouncer, RabbitMQ, Redis, MinIO |
| Node.js | 22 | the ERP API & web |
| pnpm | 9+ | the ERP monorepo |
| Flutter | 3.44+ | the mobile apps |
| Python | 3.11+ | the AI service |
| psql | 16 | seeding / inspection |

The **backend, web console, and AI service** live in the MetaXperts ERP monorepo (`/erp`). This repo (`/rms`)
holds the four Flutter apps, the demo seed, and docs.

---

## 2. Bring up the backend

From the **ERP repo**:

```bash
# 2.1 — infra (Postgres :55432 direct / :6432 pooled, RabbitMQ :5672, Redis, MinIO)
docker compose -f infra/docker-compose.yml up -d

# 2.2 — run migrations (creates 25 RLS-protected restaurant_* tables, among others)
pnpm --filter @app/api migration:run

# 2.3 — start the API with the reaction workers ON (so the GL journal posts on settle)
API_PORT=3399 NODE_ENV=development \
  WORKER_REACTIONS_ENABLED=1 OUTBOX_RELAY_ENABLED=1 \
  pnpm --filter @app/api dev
```

`WORKER_REACTIONS_ENABLED` + `OUTBOX_RELAY_ENABLED` turn on the outbox relay and the idempotent
consumers — without them, settlement still deducts inventory and captures COGS (synchronous), but the GL
journal (asynchronous) will not post.

Health check: `curl http://127.0.0.1:3399/health/ready` → `200`.

---

## 3. Seed the demo restaurant

From **this repo**, with the API running:

```bash
API_URL=http://127.0.0.1:3399 \
OWNER_URL=postgresql://metaxperts:metaxperts@127.0.0.1:55432/metaxperts \
  bash scripts/seed-demo.sh
```

This provisions the **Karahi Point** tenant and seeds, in order:

1. a platform super-admin + the tenant (enterprise plan), with `restaurant`/`inventory`/`finance`/`crm` enabled;
2. a finance **chart of accounts** and the restaurant **GL mapping** (cash, sales, tax, COGS, inventory);
3. a kitchen store + six **ingredients stocked in grams** with opening stock;
4. a **photo menu** — 4 categories, 7 items with real food images;
5. **recipes** (so settlement deducts inventory and captures COGS);
6. the **floor plan** — 2 areas, 7 tables;
7. **reservations** and a few live orders (one settled → revenue + COGS + a GL journal exist immediately).

> Login everywhere with **`chef@karahipoint.test` / `Password123!`**.

Re-running is safe: if the demo admin already exists it reuses the tenant, and if the menu is already
seeded it exits early.

---

## 4. Run the web console

From the **ERP repo** — the web talks to the API same-origin via an `/api` proxy:

```bash
# point the client at the API and start the dev server
API_PROXY_TARGET=http://localhost:3399 NEXT_PUBLIC_API_URL=/api \
  pnpm --filter @app/web dev   # → http://localhost:3001
```

Open **`/restaurant`**: Dashboard · POS · Menu · Floor · Kitchen (KDS) · Orders · Deliveries · Reservations.

---

## 5. Run the mobile apps

Each app is independent. From **this repo**:

```bash
cd rms_waiter        # or rms_manager / rms_driver / rms_customer
flutter pub get
flutter run          # pick a device/emulator, or: flutter run -d chrome
```

On the sign-in screen, tap **Server settings** and set the API address:

- Android emulator → `http://10.0.2.2:3399`
- web / desktop → `http://localhost:3399`

Then sign in with `chef@karahipoint.test` / `Password123!`.

| App | Try this |
| --- | --- |
| **Waiter** | Tap an available table → add dishes → **Place order** (fires the kitchen) → **Settle** |
| **Manager** | Watch the Dashboard KPIs, the Kitchen board, and Sales update live |
| **Driver** | Open an assigned run → **Picked up** → **Share location** → **Deliver** (enter the OTP) |
| **Customer** | Browse → add to cart → choose Delivery + address → **Place order** → watch the tracker |

> The driver's OTP is the customer's — for the demo you can read it from the DB:
> `psql "$OWNER_URL" -tAc "select otp_code from restaurant_delivery order by created_at desc limit 1"`.

---

## 6. Run the AI service

The AI service is a FastAPI app in the ERP repo (`apps/ml`). It's secured with the API's signed
service token.

```bash
cd apps/ml
# install deps (into a target dir if no venv), then run
python3 -m pip install --target ./.pydeps \
  fastapi "uvicorn[standard]" pydantic pydantic-settings PyJWT structlog "psycopg[binary]" numpy statsmodels
PYTHONPATH="$(pwd)/.pydeps" \
  SERVICE_AUTH_SECRET="$(grep ^SERVICE_AUTH_SECRET= ../../.env | cut -d= -f2-)" \
  ML_DATABASE_URL=postgresql://metaxperts:metaxperts@127.0.0.1:55432/metaxperts \
  python3 -m uvicorn app.main:app --host 127.0.0.1 --port 8201
```

Mint a token and call the three restaurant models (`TENANT` = your tenant id, `ITEM` = a menu item id):

```bash
SECRET=$(grep ^SERVICE_AUTH_SECRET= ../../.env | cut -d= -f2-)
TOKEN=$(PYTHONPATH=.pydeps python3 -c "import jwt,datetime;print(jwt.encode({'svc':'api','aud':'internal','iss':'metaxperts-api','exp':datetime.datetime.utcnow()+datetime.timedelta(hours=1)},'$SECRET','HS256'))")
H="x-service-token: $TOKEN"; A=http://127.0.0.1:8201

curl -s -XPOST $A/ml/restaurant/demand    -H "$H" -H 'content-type: application/json' -d "{\"tenantId\":\"$TENANT\",\"itemId\":\"$ITEM\",\"horizon\":7}"
curl -s -XPOST $A/ml/restaurant/prep-time  -H "$H" -H 'content-type: application/json' -d "{\"tenantId\":\"$TENANT\",\"itemId\":\"$ITEM\"}"
curl -s -XPOST $A/ml/restaurant/upsell     -H "$H" -H 'content-type: application/json' -d "{\"tenantId\":\"$TENANT\",\"basket\":[\"Chicken Karahi\"],\"top\":3}"
```

| Endpoint | What it returns |
| --- | --- |
| `demand` | next-N-day order volume for an item (ARIMA, naive fallback for short history) |
| `prep-time` | expected kitchen ETA = historical cook time × recipe × **live queue load** |
| `upsell` | items frequently ordered alongside the basket (market-basket confidence + lift) |

---

## 7. The money loop, explained

Settling one bill runs this chain — proven end to end on a real ledger:

```
① take order    POS/app → lines priced in integer minor units
② fire kitchen  KDS tickets routed by station (auto-fires if config.auto_fire_kitchen)
③ settle        tender + PRA tax (bp) + rounding → order status SETTLED
④ explode recipe for each line, deduct the valued inventory ledger (weighted-avg)
⑤ capture COGS  moved.unitCost × qty → order_item.cogs_minor (synchronous, in the settle tx)
⑥ emit event    restaurant.bill_settled written to the transactional outbox
⑦ relay         outbox → RabbitMQ
⑧ GL consumer   builds a balanced JV and posts via FinanceService (idempotent per order)
```

A cash sale posts, e.g.:

```
Dr Cash 1,810.00
    Cr Restaurant Sales   1,560.00     (net sales)
    Cr Sales Tax Payable    249.60     (16% PRA)
    Cr Rounding               0.40
Dr Cost of Goods Sold 346.00
    Cr Inventory            346.00
  ── debits 2,156.00 == credits 2,156.00 ✓
```

Steps ④–⑤ are **synchronous** (atomic with the bill). Steps ⑥–⑧ are **asynchronous**; they need the
workers from step 2.3.

---

## 8. Acceptance / E2E test

A single repeatable gate walks the whole path. From the **ERP repo**:

```bash
bash apps/api/test/restaurant-e2e.sh        # 22 checks
# or as part of the suite:
pnpm --filter @app/api test:e2e
```

It provisions a throwaway tenant, spins up its own API instance (workers on), and asserts: setup → order →
KDS fire → settle (tax, COGS, stock) → **balanced GL journal** → double-settle rejected → delivery with
OTP → reservation → **RLS isolation** → fiscal config. Expect `RESULT: 22 passed, 0 failed`.

---

## 9. Troubleshooting

| Symptom | Fix |
| --- | --- |
| GL journal never posts | The API must run with `WORKER_REACTIONS_ENABLED=1 OUTBOX_RELAY_ENABLED=1` (step 2.3). |
| App shows *Login failed* | Check **Server settings** points at a reachable API. Android emulator uses `10.0.2.2`, not `localhost`. |
| App images blank on **web** | Flutter web (CanvasKit) can't draw non-CORS images to canvas — they render fine on a real device. |
| `settle` 500 "invalid input syntax for type integer" | Ingredients must be stocked in whole units (grams/ml/pieces) — the inventory ledger is integer-only; the seed already does this. |
| Web can't reach the API | The web CSP is `connect-src 'self'`; the client must call the same-origin `/api` proxy (`NEXT_PUBLIC_API_URL=/api` + `API_PROXY_TARGET`). |
| AI endpoint 401 | Mint the service token with the **same** `SERVICE_AUTH_SECRET` the service runs with (aud `internal`, iss `metaxperts-api`). |
