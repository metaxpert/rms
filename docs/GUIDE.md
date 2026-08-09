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

## 8. Receipt printers & barcode scanning

### 8.1 How printing works

The API never talks to a printer. It **renders a document and queues a print job**; a small **print
agent** running on the restaurant's own network claims jobs for its printer and pushes the bytes.

```
order fires ─→ KOT job queued ─┐
bill settled ─→ receipt job ───┤→ restaurant_print_job ←─ poll ─ print agent ─→ ESC/POS ─→ 🖨
                               │      (QUEUED → CLAIMED → PRINTED)
   POST /orders/:id/print ─────┘                         ↑ failure → back to QUEUED (retries)
```

Why a spool rather than a direct connection:

- A cloud API cannot reach `192.168.x.x`. The agent dials outward, so no port forwarding.
- A printer that is **off, jammed or out of paper delays a slip — it never fails an order**. The job
  waits in the queue; the guest's bill is already settled and posted.
- Every slip is auditable: what was printed, for which bill, on which device, how many attempts.

### 8.2 Register a printer

In the web console: **Restaurant → Printers → +**. One row per physical device:

| Field | Meaning |
| --- | --- |
| `key` | What the agent is configured with, e.g. `till-1`, `kitchen-grill` |
| `kind` | `RECEIPT` (guest bill), `KITCHEN` (KOT), `LABEL`, `REPORT` |
| `connection` | `NETWORK` (host + port 9100), `USB`/`BLUETOOTH` (device path), `BROWSER`, `CLOUD` |
| `stationKey` | Binds a kitchen printer to one station, so that station's tickets route to it |
| `charsPerLine` | `32` = 58 mm paper, `42`/`48` = 80 mm |

Routing is automatic: a KOT goes to the kitchen printer bound to its station (falling back to any
kitchen printer at the branch); a bill goes to the branch's default receipt printer. If nothing is
configured yet the job is still queued — the first matching agent to poll adopts it.

### 8.3 Run the print agent

On the till PC or a Raspberry Pi in the kitchen (Node 18+, no dependencies):

```bash
API_URL=http://localhost:3399 \
RMS_EMAIL=chef@karahipoint.test RMS_PASSWORD='Password123!' \
PRINTER_KEY=till-1 \
TARGET=tcp://192.168.1.50:9100 \
node scripts/print-agent.js
```

`TARGET` selects the device: `tcp://host:port` for a network printer, `file:///dev/usb/lp0` for USB,
or omit it for a **dry run** that prints the slip to the terminal — the fastest way to see the layout
without hardware. The login needs the `restaurant:print` permission.

### 8.4 What comes out

A **kitchen ticket** carries no prices — station name in double size, quantities, modifiers and
allergy notes:

```
          HOT KITCHEN
================================
KOT-000026                 16:28
Order                 ORD-000021
Type                     DINE_IN
Covers                         3
================================
2 x Chicken Karahi
   Extra hot, No coriander
   ** Guest is allergic to nuts
```

A **bill** carries branding, the priced lines, the tax breakdown, how it was paid, and either the
fiscal QR (once PRA/FBR accepts the invoice) or a scannable order barcode:

```
         Karahi Point
            Gulberg
------------------------------------------
Bill                            ORD-000021
Date                 27 Jul 2026, 04:30 pm
------------------------------------------
2 x Beef Nihari                   2,300.00
------------------------------------------
Subtotal                          2,300.00
Sales tax                           368.00
==========================================
TOTAL PKR                         2,668.00
==========================================
CASH                              3,168.00
Change                              500.00
             || ORD-000021 ||
```

Line amounts and the subtotal share one tax-exclusive basis, so a guest adding up the right-hand
column arrives at the printed subtotal. An unsettled order prints as a **pro-forma**, never a tax
invoice. A cash sale kicks the drawer; a reprint is banner-marked so it cannot pass as the original.

### 8.5 Scanning

One endpoint, `POST /restaurant/scan`, resolves whatever the scanner produced:

| Scanned | Resolves to | Typical use |
| --- | --- | --- |
| `mx://table/<token>` | the table + its open tab | guest scans the table sticker; waiter opens the tab |
| `ORD-000021` | the order | scan the printed bill to reprint or settle |
| `KOT-000026` | the kitchen ticket | trace a slip back to its order |
| reservation code | the booking | check a guest in at the door |
| `DLV-000002` | the delivery run | rider handover |
| product barcode / SKU | the menu item | ring up packaged goods |
| ingredient SKU | the inventory product | kitchen store receiving |

`POST /restaurant/orders/:id/scan-add` goes one step further and puts the scanned product straight on
the ticket, priced from the menu. Both the web POS and the waiter app expose this as a plain text
field — every restaurant barcode scanner is a **keyboard wedge** that types the code and presses
Enter, so it works with real hardware without a driver and stays usable by typing when one dies.

Table QR stickers are issued per table (`GET /restaurant/tables/:id/qr`) and can be **rotated**
(`POST .../qr/rotate`) — a photographed sticker is invalidated without changing the table's code.

### 8.6 Generating codes

Scanning is only half the loop — the system also **produces** the codes it later reads.

**Barcodes for menu items.** Restaurant → Menu → pick an item → **Generate barcode**. With no value
supplied the API mints an **internal EAN-13** with a correct check digit, using the GS1 **in-store
range (prefixes 20–29)** that is reserved for codes meaningful only inside one business — so an
own-menu code can never collide with a real manufacturer's product. Recording a real supplier EAN
instead is just `{"value":"5449000000996"}`; a wrong check digit is rejected up front rather than
failing at the till.

```bash
POST /restaurant/items/:id/barcode            # mint (idempotent — returns the existing code)
POST /restaurant/items/:id/barcode  {"regenerate":true}   # replace (invalidates printed labels)
POST /restaurant/items/barcodes/generate-missing          # bulk: every item that lacks one
```

**Images.** Any value renders as an image, straight from the API:

```bash
GET /restaurant/codes/qr?value=mx://table/AbCd1234&format=svg|png&size=256
GET /restaurant/codes/barcode?value=2000000000015          # symbology inferred
GET /restaurant/codes/barcode?value=ORD-000021&symbology=CODE39
```

SVG is the default because a barcode rasterised at the wrong resolution simply will not scan; PNG is
there for surfaces that can't draw SVG. The web console shows both inline and offers SVG/PNG
downloads.

**Printed labels.** The same spool that carries bills and kitchen tickets also carries labels, routed
to a `LABEL` printer when one exists and to the receipt printer otherwise:

```bash
POST /restaurant/tables/:id/qr/print   {"copies":2,"caption":"Scan to order"}
POST /restaurant/items/:id/barcode/print
```

A product label prints a **native EAN-13** ESC/POS command (`GS k 67`), not CODE39 digits that merely
look like a barcode — a retail scanner validates the symbology and check digit, so the difference is
whether the label works at all.


**Bulk printing.** Both catalogues can print a whole sheet of labels at once, for ordinary sticker
paper on an ordinary printer:

- **Restaurant → Menu → Print** — every listed dish (respects the search and category filter)
- **Inventory → Products → Print barcodes** — every listed product, with SKU and sell price

Choose 2/3/4 labels per row and how many copies of each, then print. Labels never split across a page
break, and the app chrome is hidden from the printout. A thermal label printer is the other path:
`POST /restaurant/items/:id/barcode/print` sends one label at a time through the print spool.

**Inventory products.** The shared catalogue carries barcodes too (`inventory_product.barcode`):

```bash
POST /inventory/products            {"sku":"ING-BEEF","name":"Beef","barcode":"5449000000996"}
POST /inventory/products/:id/barcode                     # mint one (idempotent)
POST /inventory/products/barcodes/generate-missing       # bulk
GET  /inventory/products/by-code?code=2000000000091      # barcode first, then SKU
```

In the UI: the **Add product** form has a Barcode field (leave blank to mint later), each product's
detail pane has a **Generate barcode** panel, and the products header carries the same bulk button.

**Codes are unique across the whole business.** Minting draws from **one tenant-wide counter**
(`code_seq`), not a per-module one — two modules each counting from 1 would issue the same code, and
scanning a carton of beef in the store would ring up a chicken dish. Both catalogues are also checked
before a code is handed out.

**Shared rendering.** Image endpoints are module-agnostic and **not** gated behind the restaurant
feature, because a tenant with only Inventory still needs to print product codes:

```bash
GET /codes/qr?value=…&format=svg|png&size=256
GET /codes/barcode?value=…&symbology=EAN13|CODE39
```

**Sticker sheet.** Restaurant → Floor → **QR sheet** renders every table's QR as a printable grid
(issuing a token for any table that lacks one), ready to cut out and stick down. Tokens are opaque
and rotatable, so a photographed sticker is invalidated without changing the table's code.

---

## 9. Acceptance / E2E test

A single repeatable gate walks the whole path. From the **ERP repo**:

```bash
bash apps/api/test/restaurant-e2e.sh        # 94 checks
# or as part of the suite:
pnpm --filter @app/api test:e2e
```

It provisions a throwaway tenant, spins up its own API instance (workers on), and asserts: setup → order →
KDS fire → settle (tax, COGS, stock) → **balanced GL journal** → double-settle rejected → delivery with
OTP → reservation → **RLS isolation** → multi-branch → **printing** (routing, spool claim, ESC/POS bytes,
receipt arithmetic, retry) → **scanning** (table QR, bill, rotation, scan-to-add) → **code generation** (EAN-13 minting,
QR/barcode images, labels) → fiscal config.
Expect `RESULT: 94 passed, 0 failed`.

---

## 10. Troubleshooting

| Symptom | Fix |
| --- | --- |
| GL journal never posts | The API must run with `WORKER_REACTIONS_ENABLED=1 OUTBOX_RELAY_ENABLED=1` (step 2.3). |
| App shows *Login failed* | Check **Server settings** points at a reachable API. Android emulator uses `10.0.2.2`, not `localhost`. |
| App images blank on **web** | Flutter web (CanvasKit) can't draw non-CORS images to canvas — they render fine on a real device. |
| `settle` 500 "invalid input syntax for type integer" | Ingredients must be stocked in whole units (grams/ml/pieces) — the inventory ledger is integer-only; the seed already does this. |
| Web can't reach the API | The web CSP is `connect-src 'self'`; the client must call the same-origin `/api` proxy (`NEXT_PUBLIC_API_URL=/api` + `API_PROXY_TARGET`). |
| AI endpoint 401 | Mint the service token with the **same** `SERVICE_AUTH_SECRET` the service runs with (aud `internal`, iss `metaxperts-api`). |
