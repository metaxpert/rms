# MetaXperts RMS — Deployment & Operator's Guide

**For the person putting this on a real server.** This guide takes you from a bare Linux box to a
live restaurant running on the RMS — taking orders, firing the kitchen, settling bills, and posting the
accounting automatically. No prior knowledge of the codebase is assumed. Every command is copy-pasteable.

> Looking for a quick *developer* spin-up on your laptop instead? See [`GUIDE.md`](./GUIDE.md).
> This document is about **running it for real**.

**Contents**

- [1. Understand what you're deploying (read this first)](#1-understand-what-youre-deploying-read-this-first)
- [2. Standalone vs. integrating with an existing ERP](#2-standalone-vs-integrating-with-an-existing-erp)
- [3. Before you begin — prerequisites](#3-before-you-begin--prerequisites)
- [4. Path A — Deploy a standalone RMS](#4-path-a--deploy-a-standalone-rms)
- [5. Path B — Add RMS to an existing MetaXperts ERP](#5-path-b--add-rms-to-an-existing-metaxperts-erp)
- [6. Make it *your* restaurant (first-run setup)](#6-make-it-your-restaurant-first-run-setup)
- [7. Install and connect the mobile apps](#7-install-and-connect-the-mobile-apps)
- [8. Using the system day to day](#8-using-the-system-day-to-day)
- [9. Operations — backups, updates, health, security](#9-operations--backups-updates-health-security)
- [10. Troubleshooting](#10-troubleshooting)
- [11. Go-live checklist](#11-go-live-checklist)

---

## 1. Understand what you're deploying (read this first)

The RMS is **not a single app**. It's a small platform made of a shared backend and several front-ends
that all talk to it:

| Piece | What it is | Where it lives |
| --- | --- | --- |
| **Backend (API)** | The brain. Menus, orders, kitchen, payments, inventory, accounting, deliveries. | MetaXperts ERP repo (`apps/api`) |
| **Web console** | The manager's browser dashboard — POS, floor designer, kitchen board, reports. | ERP repo (`apps/web`) |
| **AI service** | Optional. Demand forecast, prep-time, upsell suggestions. | ERP repo (`apps/ml`) |
| **4 mobile apps** | Waiter, Manager, Driver, Customer. | **This repo** (`rms_waiter/`, …) |
| **Database & plumbing** | Postgres, RabbitMQ, Redis, file storage. | Runs in Docker |

The important thing to grasp: **the restaurant system is a "module" baked inside the larger MetaXperts
ERP.** You don't install "RMS" as a separate server. You run the MetaXperts ERP, and you switch on the
*restaurant* feature. Everything below follows from that one fact.

```
        ┌─────────────────────────────────────────────────┐
        │              MetaXperts ERP (one API)            │
        │  ┌──────────┐ ┌──────────┐ ┌─────────┐ ┌──────┐  │
        │  │Restaurant│ │Inventory │ │ Finance │ │ CRM  │  │  ← modules, toggled per company
        │  └──────────┘ └──────────┘ └─────────┘ └──────┘  │
        └───────▲───────────▲───────────▲───────────▲──────┘
                │           │           │           │
          Web console   Waiter app  Manager app  Customer/Driver apps
```

The restaurant module **needs three other modules to work**: **Inventory** (to deduct ingredients and cost
your dishes), **Finance** (to post the sales and cost to the general ledger), and **CRM** (customers).
These are turned on automatically alongside it.

---

## 2. Standalone vs. integrating with an existing ERP

You asked for both. Here is the honest difference — it's smaller than you might expect, because **both use
the exact same software**. The difference is only *which features are switched on for the company*.

| | **Standalone RMS** (Path A) | **Integrate with existing ERP** (Path B) |
| --- | --- | --- |
| **Situation** | You just want a restaurant system. You have no other MetaXperts ERP. | You already run the MetaXperts ERP for accounting/inventory/etc. and want to add the restaurant. |
| **What you do** | Deploy the ERP fresh, create a company with **only** Restaurant (+ Inventory, Finance, CRM) switched on. | Keep your existing deployment. Make sure it's a version that contains the restaurant module, then **switch the Restaurant feature on** for your company. |
| **Deploy work** | Full install (Section 4). | Upgrade + a feature toggle (Section 5). |
| **Result** | A server that behaves like a dedicated restaurant product — every non-restaurant screen is simply hidden/blocked for that company. | Your staff see the new Restaurant section appear next to your existing modules; it shares your customers, inventory, and books. |

**In plain terms:** "standalone" and "integrated" are the *same build*. Switching features on/off is a
per-company setting stored in the database (`tenant_feature_entitlement`), not a different download. A
company that has only Restaurant enabled *is* a standalone RMS. A company that has Restaurant enabled
alongside HR, Sales, Purchasing, etc. *is* an integrated RMS. You can even start standalone and light up
more modules later without redeploying.

> **Multi-tenant note:** one ERP deployment can serve many companies ("tenants"), each with its own data
> (isolated by the database's row-level security) and its own feature switches. So a single server can host
> both a pure-restaurant customer and a full-ERP customer at the same time.

---

## 3. Before you begin — prerequisites

**A server.** A Linux VPS or cloud VM. For a single busy restaurant, start with roughly **4 vCPU / 8 GB
RAM / 40 GB SSD** and grow from there. Ubuntu 22.04+ is a safe choice.

**Software on the server:**

| Tool | Why | Install check |
| --- | --- | --- |
| **Docker Engine + Compose plugin** | Runs the whole stack. | `docker --version && docker compose version` |
| **git** | To fetch the code. | `git --version` |
| **A domain name** (recommended) | So staff and customers reach it over HTTPS. | — |

**Software only on your laptop (to build the mobile apps):**

| Tool | Version | Why |
| --- | --- | --- |
| **Flutter** | 3.44+ | Build the 4 mobile apps (`flutter build apk` / `ipa` / `web`). |

**Access to two repositories:**

1. **The MetaXperts ERP repo** — the backend, web console, and AI service (private).
2. **This repo (`rms`)** — the four Flutter apps, the demo seed, and these docs.

> If you only have this `rms` repo, you have the phones and the docs but not the brain. You need the ERP
> repo (or a pre-built ERP image) to run the backend. Ask your MetaXperts contact for access.

---

## 4. Path A — Deploy a standalone RMS

This produces a fresh, self-contained restaurant server. Do everything here **on the server**, inside the
**ERP repository**.

### 4.1 Get the code

```bash
git clone <your-metaxperts-erp-repo-url> erp
cd erp
```

### 4.2 Set your secrets

The production stack ships with **placeholder secrets that you must change** before going live. Generate
strong random values and put them in a `.env` file at the repo root (the compose file reads it):

```bash
cat > .env <<EOF
# --- change every one of these to your own random values ---
JWT_ACCESS_SECRET=$(openssl rand -hex 32)
JWT_REFRESH_SECRET=$(openssl rand -hex 32)
SERVICE_AUTH_SECRET=$(openssl rand -hex 32)

# where the browser/apps reach the API (see 4.6 for HTTPS)
CORS_ORIGINS=https://rms.yourdomain.com
PUBLIC_API_URL=/api
EOF
```

| Secret | What it protects |
| --- | --- |
| `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` | Staff/customer login tokens. Anyone who knows these can forge logins. |
| `SERVICE_AUTH_SECRET` | The token the AI service uses to call the API. |
| `CORS_ORIGINS` | Which website addresses the browser API will accept requests from. |

> The database, RabbitMQ, and object-storage passwords also default to demo values in the compose file.
> For a hardened install, change those too and/or use Docker secrets (`*_FILE` env vars) — see the ERP
> repo's **`docs/runbook.md`** for the secrets-file convention. For a first internal deployment the
> defaults work, but treat the three secrets above as mandatory.

### 4.3 Start the whole stack

The production compose file brings up **everything** — database, message broker, cache, storage, the API,
the web console, the AI service, and monitoring — in one command:

```bash
docker compose -f infra/docker-compose.prod.yml up -d --build
```

This can take several minutes the first time (it builds images). When it finishes:

| Service | Reachable at (on the server) |
| --- | --- |
| API | `http://127.0.0.1:3300` |
| Web console | `http://127.0.0.1:3001` |
| AI service | `http://127.0.0.1:8088` |
| Grafana (monitoring) | `http://127.0.0.1:3004` (admin/admin) |

> In the production stack the **background workers are already switched on** (`WORKER_REACTIONS_ENABLED`
> and `OUTBOX_RELAY_ENABLED` are `true`). That's what makes the accounting post automatically when a bill
> is settled — you don't have to do anything extra.

### 4.4 Create the database tables (run migrations)

The stack is running but the database is empty. Create the schema (this builds **all** ERP tables,
including the 25 restaurant tables — it's safe and only creates what's missing):

```bash
bash infra/scripts/migrate-prod.sh
```

Check the API is healthy:

```bash
curl -s http://127.0.0.1:3300/health/ready
# → should report status "ok"
```

### 4.5 Create your restaurant company (with only Restaurant switched on)

This is the step that makes it "standalone." You create a **platform super-admin** once (the operator
account that can create companies), then provision your restaurant company and switch on exactly the
restaurant feature set.

**a) Try it with the demo first (optional but recommended).** This repo ships a one-command seed that
creates a fully-worked example restaurant ("Karahi Point") so you can log in and see everything working
before doing it for real. Run it from **this `rms` repo**, but from inside the **ERP repo's** folder so it
can hash the admin password:

```bash
# from the ERP repo directory, pointing at this rms repo's script:
API_URL=http://127.0.0.1:3300 \
OWNER_URL=postgresql://metaxperts:metaxperts@127.0.0.1:55433/metaxperts \
  bash /path/to/rms/scripts/seed-demo.sh
```

> The `OWNER_URL` above uses port **55433**, which the production stack exposes for admin/migration access
> via the `docker-compose.prod.local.yml` override. If your Postgres isn't published to the host, run the
> seed from a container on the `erp-prod` network, or temporarily add that override:
> `docker compose -f infra/docker-compose.prod.yml -f infra/docker-compose.prod.local.yml up -d`.

Log in to the web console (Section 8) with **`chef@karahipoint.test` / `Password123!`** and click around.
When you're happy, move on to creating your *real* company below.

**b) Create your real restaurant company.** Log in as the super-admin and provision a company, enabling the
restaurant feature bundle. The cleanest "standalone" setup starts from the minimal **starter** plan and
switches on only what the restaurant needs:

```bash
API=http://127.0.0.1:3300

# 1) log in as the platform super-admin (created by the seed, or bootstrap your own)
SA=$(curl -s -X POST $API/auth/login -H 'content-type: application/json' \
  -d '{"email":"YOUR-SUPERADMIN@example.com","password":"YOUR-PASSWORD"}' \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["data"]["accessToken"])')

# 2) create the company + its first admin user
TID=$(curl -s -X POST $API/tenants -H "authorization: Bearer $SA" -H 'content-type: application/json' \
  -d '{"name":"My Restaurant","adminEmail":"owner@myrestaurant.com","adminPassword":"ChangeMe123!","plan":"starter"}' \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["data"]["tenant"]["id"])')

# 3) switch on Restaurant and its required modules
for f in inventory finance crm restaurant; do
  curl -s -X PATCH $API/tenants/$TID/features/$f -H "authorization: Bearer $SA" \
    -H 'content-type: application/json' -d '{"enabled":true}' >/dev/null
done
echo "Company created: $TID"
```

That's it — this company now behaves as a dedicated RMS. Every non-restaurant screen is automatically
hidden and blocked for it (the API returns "feature not enabled" for anything you didn't switch on).

> **Where does the super-admin come from?** The demo seed creates one for you by inserting an operator
> account directly. In a clean production install, create your first super-admin the same way (the seed
> script shows the exact SQL insert with a hashed password), then use it to provision all real companies
> through the API as above. Keep those credentials safe — this account can create and configure every
> company on the server.
>
> **On a server that is already seeded, use `scripts/create-superadmin.sh` instead:**
>
> ```bash
> bash scripts/create-superadmin.sh sa@yourdomain.com 'a-strong-password'
> ```
>
> `seed-demo.sh` only bootstraps a super-admin on the same branch where it creates the demo tenant, so
> re-running it against a server that already has `chef@karahipoint.test` takes the "reusing the tenant"
> path and never creates one. That is how a live server ends up seeded, working, and with no account
> able to reach **Platform → Companies**. The script performs the same insert on its own, idempotently,
> then proves the result by signing in and checking the token really carries `SUPER_ADMIN`.
>
> Provisioning has a UI, incidentally — the API calls above are the same thing the console's
> **Platform → Companies** page does, and that page renders only for `SUPER_ADMIN`.

### 4.6 Put it behind HTTPS (a domain)

For staff and customers to reach it securely, terminate TLS in front of the web + API. The ERP repo
includes an **Nginx** config under `infra/nginx/` for exactly this. In short:

- Point your domain (e.g. `rms.yourdomain.com`) at the server.
- Nginx serves the web console and proxies `/api` to the API container.
- Set `CORS_ORIGINS` (Section 4.2) to that HTTPS address and rebuild the web image so the browser knows the
  API lives at `/api`.

Follow the TLS section of the ERP's `docs/runbook.md` for certificate setup. Once live, the manager opens
`https://rms.yourdomain.com`, and the mobile apps point at `https://rms.yourdomain.com/api`.

**Standalone deployment done.** Continue to [Section 6](#6-make-it-your-restaurant-first-run-setup) to load
your menu, floor, and accounts.

---

## 5. Path B — Add RMS to an existing MetaXperts ERP

If you already operate the MetaXperts ERP (for accounting, inventory, sales, etc.), adding the restaurant
is **not a new deployment** — it's an upgrade plus a switch. Three steps.

### 5.1 Make sure your deployment contains the restaurant module

The restaurant lives *inside* the ERP codebase. If your running ERP predates it, you need to update to a
build that includes it. Update your ERP checkout / image to the version that contains
`apps/api/src/modules/restaurant` and the two restaurant migrations
(`…-RestaurantCore.ts`, `…-RestaurantOrders.ts`), then rebuild and roll out as you normally deploy:

```bash
cd erp
git pull                 # get the version with the restaurant module
docker compose -f infra/docker-compose.prod.yml up -d --build   # rebuild + rolling restart
```

Your existing data is untouched — this only replaces the application containers.

### 5.2 Run the new migrations

Apply the schema. This is **additive**: the restaurant migrations create only new `restaurant_*` tables and
add links *from* them *to* your existing inventory and customer tables. They do **not** alter or touch your
existing modules' data.

```bash
bash infra/scripts/migrate-prod.sh
```

> Migrations are idempotent — already-applied ones are skipped, only the new restaurant ones run. As always,
> take a database backup first (Section 9). Do it in a maintenance window if you're cautious.

### 5.3 Switch the Restaurant feature on for your company

Now light it up for the companies that need it. As a platform super-admin:

```bash
API=http://127.0.0.1:3300     # your existing API address
SA=<super-admin access token>  # log in as in 4.5

# your existing company id:
TID=<your-tenant-id>

# restaurant needs inventory + finance + crm; enable any that aren't already on:
for f in inventory finance crm restaurant; do
  curl -s -X PATCH $API/tenants/$TID/features/$f -H "authorization: Bearer $SA" \
    -H 'content-type: application/json' -d '{"enabled":true}' >/dev/null
done
```

Within a minute (feature flags are cached for ~60s), your staff will see a new **Restaurant** section in
the web console, right alongside your existing modules. Because it shares the same company, the restaurant
reuses your **existing customers (CRM), inventory items and warehouses, and chart of accounts** — its sales
and food-cost post straight into the books you already keep.

**Integration done.** Continue to [Section 6](#6-make-it-your-restaurant-first-run-setup) — though if you
already have inventory and a chart of accounts, you'll mostly just add the restaurant-specific pieces
(GL mapping, menu, floor).

---

## 6. Make it *your* restaurant (first-run setup)

Whether standalone or integrated, a new restaurant needs a handful of things configured before it can take
and settle bills correctly. Most of this is done in the **web console**; a couple of one-time links are set
via the API. Here's the checklist, in order.

### 6.1 Accounting links (so bills post to the ledger)

The restaurant needs to know **which ledger accounts** to post to. Create these accounts in Finance (or
reuse existing ones if integrating), then set the mapping. Five accounts are needed:

| Account | Type | Used for |
| --- | --- | --- |
| Cash in Hand | Asset (Cash) | money received |
| Inventory | Asset | value of ingredients on hand |
| Restaurant Sales | Revenue | net sales |
| Sales Tax Payable | Liability | tax collected (e.g. PRA 16%) |
| Cost of Goods Sold | Expense | food cost of what you sold |

Then tell the restaurant which is which (one-time, via API):

```bash
curl -s -X PUT $API/restaurant/gl-config -H "authorization: Bearer $TOKEN" \
  -H 'content-type: application/json' -d '{
    "cashAccountId":"<cash id>", "revenueAccountId":"<sales id>",
    "taxAccountId":"<tax id>",  "cogsAccountId":"<cogs id>",
    "inventoryAccountId":"<inventory id>" }'
```

> The demo seed does all of this automatically — read `scripts/seed-demo.sh` to see the exact account
> structure and copy it.

### 6.2 A kitchen store + your ingredients

Create a **warehouse** (your kitchen store) and stock your **ingredients** in whole units — **grams, ml, or
pieces** (never kilograms). This matters: the inventory ledger holds whole numbers, and recipes are measured
in those same base units. Then mark that warehouse as the restaurant's default so settlement knows where to
deduct from:

```bash
curl -s -X PUT $API/restaurant/config -H "authorization: Bearer $TOKEN" \
  -H 'content-type: application/json' -d '{"defaultWarehouseId":"<warehouse id>","currency":"PKR","defaultTaxBp":1600}'
```

(`defaultTaxBp` is tax in basis points — `1600` = 16%.)

### 6.3 Menu, floor, and recipes (in the web console)

Now the fun part — all point-and-click in the web console:

- **Menu** → create categories (Curries, BBQ, Breads…), then items with prices, prep time, kitchen station,
  and a photo. Optionally add modifier groups (spice level, add-ons).
- **Floor** → draw your dining areas and drag tables into place (shapes, capacity, position).
- **Recipes** → for each dish, list its ingredients and quantities. **This is what turns a sale into a real
  food-cost and inventory deduction.** A dish with no recipe still sells fine — it just won't cost itself.

### 6.4 Fiscal / tax authority (Pakistan)

If you must report invoices to a revenue authority (PRA, FBR, SRB, KPRA, BRA), set it per branch under the
restaurant fiscal config. Until you add real credentials it runs in a safe sandbox mode. This is optional
for day-one operation.

---

## 7. Install and connect the mobile apps

The four apps are in **this repo**. Build each once and distribute to the right staff.

| App | Folder | Who uses it |
| --- | --- | --- |
| Waiter | `rms_waiter/` | floor staff — take & fire orders, settle |
| Manager | `rms_manager/` | owner/manager — live dashboard |
| Driver | `rms_driver/` | delivery riders — pickup, GPS, OTP |
| Customer | `rms_customer/` | diners — browse, order, track |

### Build an app

```bash
cd rms_waiter          # or rms_manager / rms_driver / rms_customer
flutter pub get
flutter build apk      # Android → build/app/outputs/flutter-apk/app-release.apk
# flutter build ipa    # iOS (needs a Mac + Apple developer account)
# flutter build web    # or serve it as a web app
```

Install the APK on the staff phones (or publish to the stores / your MDM).

### Connect an app to your server

Every app has a **Server settings** option on its sign-in screen. Point it at your API:

- Production with a domain → `https://rms.yourdomain.com/api`
- On the same LAN, no domain → `http://<server-ip>:3300`
- Android **emulator** during testing → `http://10.0.2.2:3300`

Then staff sign in with the user accounts you created for them (the owner admin, or additional staff users
you add). Everyone can use the same login the manager uses to start, but for a real deployment create
separate staff accounts.

---

## 8. Using the system day to day

### The web console (manager's cockpit)

Open `https://rms.yourdomain.com` and go to the **Restaurant** section:

| Screen | What you do there |
| --- | --- |
| **Dashboard** | Live KPIs — open bills, covers, kitchen tickets, deliveries, bookings. |
| **POS** | Take an order at the counter: pick channel/table → tap dishes → place → send to kitchen → settle. |
| **Menu** | Manage categories, items, prices, photos, modifiers, 86 (mark sold-out). |
| **Floor** | Design areas and tables; see live table status. |
| **Kitchen (KDS)** | The live kitchen board — tickets per station with cook timers; start → ready → bump. |
| **Orders / Deliveries / Reservations** | Track and manage each. |

### The daily flow

```
Waiter app: pick a table → add dishes → Place → Send to kitchen
        ↓
Kitchen board: ticket appears at the right station → cook → Ready → Bump
        ↓
Waiter app: Settle (cash/card) → prints/records the bill
        ↓
Automatically: ingredients deducted · food-cost captured · a balanced journal
               voucher posted to the general ledger
```

That last line is the point of the whole system: **you don't do the accounting — settling the bill does
it.** Every settled bill deducts the recipe's ingredients from inventory at weighted-average cost, records
the exact cost of goods sold, and posts a balanced double-entry voucher (Cash / Sales / Tax / COGS /
Inventory) to your ledger.

### Roles at a glance

- **Waiter app** — floor → table → order → fire kitchen → settle.
- **Manager app** — a read-only live dashboard (sales, kitchen, covers) that auto-refreshes.
- **Driver app** — assigned runs → *Picked up* → *Share location* (GPS) → *Deliver* (enter the customer's
  OTP).
- **Customer app** — browse the photo menu → cart → delivery/takeaway → live order tracker.

---

## 9. Operations — backups, updates, health, security

**Health.** Point your uptime monitor at `GET /health/ready` on the API — it returns 200 only when the
database and cache are reachable (and 503 while draining during a restart, so a load balancer pulls it
cleanly). The web, worker, and AI containers each expose their own health check too.

**Monitoring.** Grafana ships in the stack (`http://127.0.0.1:3004`, admin/admin — change it) with
Prometheus metrics from the API. Watch order/settlement rates and error rates here.

**Backups.** Your entire business is in Postgres. Back it up on a schedule. The ERP repo includes
`infra/scripts/backup.sh` and `restore.sh`. Test a restore before you rely on it.

**Updates / new versions.** To roll out a new build:

```bash
cd erp
git pull
docker compose -f infra/docker-compose.prod.yml up -d --build   # rolling restart
bash infra/scripts/migrate-prod.sh                              # apply any new migrations
```

The outbox design means in-flight events aren't lost across a restart. See the ERP `docs/runbook.md` for
rolling-restart and rollback details.

**Security must-dos before real customers:**

- Change the three secrets in `.env` (Section 4.2) — never ship the demo defaults.
- Change the Grafana and any database/broker default passwords.
- Serve everything over HTTPS (Section 4.6).
- Create individual staff accounts; don't share the owner login.
- Restrict who holds the platform **super-admin** — it can configure every company.

---

## 10. Troubleshooting

| Symptom | Cause & fix |
| --- | --- |
| **Bill settles but nothing posts to the ledger** | Background workers off. In the *production* stack they're on by default; if you customized env, ensure `WORKER_REACTIONS_ENABLED=1` and `OUTBOX_RELAY_ENABLED=1`. Also check the dish has a **recipe** and the **GL mapping** (6.1) + **default warehouse** (6.2) are set. |
| **Settle fails: "invalid input syntax for type integer"** | An ingredient is stocked in a fractional unit. Stock ingredients in **grams/ml/pieces**, not kilograms (6.2). |
| **App says "Login failed"** | Wrong **Server settings** address. Use `https://…/api` in production, `10.0.2.2:3300` on an Android emulator — `localhost` inside a phone points at the phone, not your server. |
| **Web console can't reach the API** | The browser API only accepts requests from addresses in `CORS_ORIGINS`, and the web app calls the API same-origin at `/api`. Set `CORS_ORIGINS` to your real HTTPS address and keep the Nginx `/api` proxy in place. |
| **Menu photos are blank in an app running in a browser** | Flutter *web* can't draw cross-origin images to its canvas. They render fine on a real phone. |
| **The Restaurant section doesn't appear for a company** | The feature isn't enabled for that company, or the ~60s feature cache hasn't refreshed. Re-run the enable loop (4.5/5.3) and wait a minute. |
| **AI endpoints return 401** | The AI service and the token must share the same `SERVICE_AUTH_SECRET`. |
| **`/health/ready` returns 503** | The API can't reach Postgres or Redis (or it's mid-restart). Check those containers are up: `docker compose -f infra/docker-compose.prod.yml ps`. |

---

## 11. Go-live checklist

- [ ] Server provisioned; Docker installed; domain pointed at it.
- [ ] ERP repo cloned; **three secrets changed** in `.env`.
- [ ] `docker compose … prod.yml up -d --build` succeeded; all containers healthy.
- [ ] `migrate-prod.sh` run; `GET /health/ready` returns ok.
- [ ] HTTPS/Nginx configured; `CORS_ORIGINS` set to the real address.
- [ ] Platform super-admin secured; demo seed reviewed then **real company created**.
- [ ] Restaurant + Inventory + Finance + CRM enabled for the company.
- [ ] GL accounts created and **GL mapping set**; **default warehouse** set; ingredients stocked in base units.
- [ ] Menu, floor, and recipes entered in the web console.
- [ ] Staff accounts created; the four apps built and pointed at the API.
- [ ] Backups scheduled and a restore tested; Grafana password changed.
- [ ] A full test order run end to end: order → kitchen → settle → **ledger voucher appears**.

---

**Related docs:** [`GUIDE.md`](./GUIDE.md) (developer/local setup) · [`../README.md`](../README.md)
(project overview) · `docs/overview.html` (visual system dashboard) · in the ERP repo: `docs/runbook.md`
(full operations runbook), `docs/adr/ADR-009-feature-entitlements.md`, `docs/adr/ADR-011-restaurant-vertical.md`.
