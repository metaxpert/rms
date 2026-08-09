#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# MetaXperts RMS — one-command demo seed.
#
# Stands up the "Karahi Point" demo restaurant tenant against a running MetaXperts
# ERP API: features, GL chart of accounts, inventory ingredients + stock, menu with
# real food photos, recipes (so settlement captures COGS), floor plan, reservations,
# and a few live orders. Idempotent-ish: safe to re-run (it provisions a fresh tenant
# only if the demo admin does not already exist).
#
#   API_URL=http://127.0.0.1:3399 \
#   OWNER_URL=postgresql://metaxperts:metaxperts@127.0.0.1:55432/metaxperts \
#     bash scripts/seed-demo.sh
#
# Demo login after seeding:  chef@karahipoint.test / Password123!
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

API_URL="${API_URL:-http://127.0.0.1:3399}"
OWNER_URL="${OWNER_URL:-postgresql://metaxperts:metaxperts@127.0.0.1:55432/metaxperts}"
ADMIN_EMAIL="${ADMIN_EMAIL:-chef@karahipoint.test}"
ADMIN_PW="${ADMIN_PW:-Password123!}"
SA_EMAIL="rms-demo-sa@metaxperts.local"
SA_PW="SuperAdmin123!"
PLATFORM_TENANT="11111111-1111-1111-1111-111111111111"

say() { printf '\033[1;33m[seed]\033[0m %s\n' "$1"; }
jget() { python3 -c "import sys,json,functools
d=json.load(sys.stdin)
print(functools.reduce(lambda o,k:(o or {}).get(k) if isinstance(o,dict) else None, sys.argv[1].split('.'), d) or '')" "$1" 2>/dev/null; }

command -v psql >/dev/null || { echo "psql required"; exit 1; }
curl -fsS "$API_URL/health" >/dev/null 2>&1 || { echo "API not reachable at $API_URL"; exit 1; }

# ── 1. super-admin + tenant provisioning ─────────────────────────────────────
if psql "$OWNER_URL" -tAc "SELECT 1 FROM users WHERE lower(email)=lower('$ADMIN_EMAIL') LIMIT 1" 2>/dev/null | grep -q 1; then
  say "$ADMIN_EMAIL already exists — reusing the tenant."
  TID=$(psql "$OWNER_URL" -tAc "SELECT tenant_id FROM users WHERE lower(email)=lower('$ADMIN_EMAIL')")
else
  say "bootstrapping platform super-admin"
  SA_HASH="$(node -e "require('argon2').hash(process.argv[1]).then(h=>process.stdout.write(h))" "$SA_PW" 2>/dev/null)"
  [ -z "$SA_HASH" ] && { echo "need argon2 (run from the ERP repo so node_modules is present)"; exit 1; }
  psql "$OWNER_URL" -q >/dev/null <<SQL
INSERT INTO users (tenant_id,email,password_hash,is_active,roles)
VALUES ('$PLATFORM_TENANT','$SA_EMAIL','$SA_HASH',true,'{SUPER_ADMIN}')
ON CONFLICT (lower(email)) DO UPDATE SET password_hash=EXCLUDED.password_hash, is_active=true;
SQL
  login() { curl -s -X POST "$API_URL/auth/login" -H 'content-type: application/json' -d "{\"email\":\"$1\",\"password\":\"$2\"}" | jget data.accessToken; }
  SA=$(login "$SA_EMAIL" "$SA_PW")
  [ -n "$SA" ] || { echo "super-admin login failed"; exit 1; }
  say "provisioning 'Karahi Point (Demo)'"
  TID=$(curl -s -X POST "$API_URL/tenants" -H "authorization: Bearer $SA" -H 'content-type: application/json' \
    -d "{\"name\":\"Karahi Point (Demo)\",\"adminEmail\":\"$ADMIN_EMAIL\",\"adminPassword\":\"$ADMIN_PW\",\"plan\":\"enterprise\"}" | jget data.tenant.id)
  for f in inventory finance crm restaurant; do
    curl -s -X PATCH "$API_URL/tenants/$TID/features/$f" -H "authorization: Bearer $SA" -H 'content-type: application/json' -d '{"enabled":true}' >/dev/null
  done
fi
say "tenant $TID"

login() { curl -s -X POST "$API_URL/auth/login" -H 'content-type: application/json' -d "{\"email\":\"$1\",\"password\":\"$2\"}" | jget data.accessToken; }
TOK=$(login "$ADMIN_EMAIL" "$ADMIN_PW"); [ -n "$TOK" ] || { echo "demo-admin login failed"; exit 1; }
H="authorization: Bearer $TOK"; CT='content-type: application/json'
post() { curl -s -X POST "$API_URL/$1" -H "$H" -H "$CT" -d "$2"; }
put()  { curl -s -X PUT  "$API_URL/$1" -H "$H" -H "$CT" -d "$2"; }
patch(){ curl -s -X PATCH "$API_URL/$1" -H "$H" -H "$CT" -d "$2"; }
get()  { curl -s "$API_URL/$1" -H "$H"; }
idof() { jget data.id; }
ownerq() { psql "$OWNER_URL" -tAc "$1"; }

# Skip data seeding if the menu already exists (idempotent re-runs).
if [ "$(curl -s "$API_URL/restaurant/items" -H "$H" | python3 -c 'import sys,json;print(len(json.load(sys.stdin).get("data",[])))' 2>/dev/null)" -gt 0 ] 2>/dev/null; then
  say "restaurant already seeded — done."; exit 0
fi

# ── 2. finance chart of accounts + GL config ─────────────────────────────────
say "finance chart of accounts + GL mapping"
acc() { post finance/accounts "$1" | idof; }
AST=$(acc '{"code":"1","name":"Assets","type":"ASSET","isGroup":true}')
INC=$(acc '{"code":"4","name":"Income","type":"REVENUE","isGroup":true}')
LIA=$(acc '{"code":"2","name":"Liabilities","type":"LIABILITY","isGroup":true}')
EXP=$(acc '{"code":"5","name":"Expenses","type":"EXPENSE","isGroup":true}')
CASH=$(acc "{\"code\":\"1-01\",\"name\":\"Cash in Hand\",\"parentId\":\"$AST\",\"controlType\":\"CASH\"}")
INV=$(acc "{\"code\":\"1-02\",\"name\":\"Inventory\",\"parentId\":\"$AST\"}")
SALES=$(acc "{\"code\":\"4-01\",\"name\":\"Restaurant Sales\",\"parentId\":\"$INC\"}")
TAXA=$(acc "{\"code\":\"2-01\",\"name\":\"Sales Tax Payable\",\"parentId\":\"$LIA\"}")
COGSA=$(acc "{\"code\":\"5-01\",\"name\":\"Cost of Goods Sold\",\"parentId\":\"$EXP\"}")
put restaurant/gl-config "{\"cashAccountId\":\"$CASH\",\"revenueAccountId\":\"$SALES\",\"taxAccountId\":\"$TAXA\",\"cogsAccountId\":\"$COGSA\",\"inventoryAccountId\":\"$INV\"}" >/dev/null

# ── 3. inventory: warehouse, ingredients (grams), opening stock ──────────────
say "kitchen store + ingredients (stocked in grams)"
WH=$(post inventory/warehouses '{"name":"Main Kitchen Store","code":"MKS"}' | idof)
put restaurant/config "{\"defaultWarehouseId\":\"$WH\",\"serviceModel\":\"DINE_IN\",\"channels\":[\"DINE_IN\",\"TAKEAWAY\",\"DELIVERY\"],\"currency\":\"PKR\",\"defaultTaxBp\":1600}" >/dev/null
declare -A ING
ingredient() { # sku name cost_per_gram
  local id; id=$(post inventory/products "{\"sku\":\"$1\",\"name\":\"$2\",\"unit\":\"g\",\"costPriceMinor\":$3,\"currency\":\"PKR\"}" | idof)
  post inventory/adjustments "{\"productId\":\"$id\",\"warehouseId\":\"$WH\",\"quantity\":20000,\"unitCostMinor\":$3,\"docType\":\"OPENING\"}" >/dev/null
  echo "$id"
}
ING[chicken]=$(ingredient ING-CHK "Chicken (raw)" 45)
ING[beef]=$(ingredient ING-BEEF "Beef (raw)" 80)
ING[flour]=$(ingredient ING-FLR "Flour" 12)
ING[spice]=$(ingredient ING-SPC "Spice mix" 200)
ING[ghee]=$(ingredient ING-GHE "Cooking ghee" 90)
ING[tea]=$(ingredient ING-TEA "Tea leaves" 150)

# ── 4. menu: categories + items with real photos ─────────────────────────────
say "menu categories + items (with food photos)"
cat() { post restaurant/categories "{\"name\":\"$1\"}" | idof; }
C_CUR=$(cat "Curries"); C_BBQ=$(cat "BBQ & Grill"); C_BRD=$(cat "Breads"); C_BEV=$(cat "Beverages")
IMG="https://www.themealdb.com/images/media/meals"
item() { # category name sku price prep station image
  post restaurant/items "{\"categoryId\":\"$1\",\"name\":\"$2\",\"sku\":\"$3\",\"basePriceMinor\":$4,\"taxBp\":1600,\"prepMinutes\":$5,\"stationKey\":\"$6\",\"imageKey\":\"$7\",\"currency\":\"PKR\"}" | idof
}
I_KAR=$(item "$C_CUR" "Chicken Karahi" KAR-01 132000 18 HOT_KITCHEN "$IMG/wyxwsp1486979827.jpg")
I_NIH=$(item "$C_CUR" "Beef Nihari" NIH-01 115000 12 HOT_KITCHEN "$IMG/uttupv1511815050.jpg")
I_SEK=$(item "$C_BBQ" "Seekh Kabab (6pc)" SK-06 98000 14 GRILL "$IMG/04axct1763793018.jpg")
I_TIK=$(item "$C_BBQ" "Chicken Tikka" TK-01 86000 13 GRILL "$IMG/wyxwsp1486979827.jpg")
I_NAN=$(item "$C_BRD" "Garlic Naan" NAN-02 12000 6 TANDOOR "$IMG/lmc6r51764365554.jpg")
I_ROT=$(item "$C_BRD" "Tandoori Roti" ROT-01 5000 5 TANDOOR "$IMG/hx335q1619789561.jpg")
I_CHA=$(item "$C_BEV" "Kashmiri Chai" BEV-04 22000 5 BEVERAGE "$IMG/vussxq1511882648.jpg")
# A bottled drink carries a real barcode so the POS scan-to-add path has something to scan.
I_COL=$(item "$C_BEV" "Cola 500ml" BEV-10 12000 0 BEVERAGE "$IMG/uttupv1511815050.jpg")
patch "restaurant/items/$I_COL" '{"barcode":"5449000000996"}' >/dev/null

# ── 5. recipes (drive COGS) — quantities in grams ────────────────────────────
say "recipes → inventory COGS"
recipe() { put "restaurant/items/$1/recipe" "$2" >/dev/null; }
recipe "$I_KAR" "{\"yieldQty\":1,\"ingredients\":[{\"productId\":\"${ING[chicken]}\",\"qtyPerYieldMilli\":400,\"wasteBp\":500},{\"productId\":\"${ING[ghee]}\",\"qtyPerYieldMilli\":50},{\"productId\":\"${ING[spice]}\",\"qtyPerYieldMilli\":20}]}"
recipe "$I_NIH" "{\"yieldQty\":1,\"ingredients\":[{\"productId\":\"${ING[beef]}\",\"qtyPerYieldMilli\":350,\"wasteBp\":500},{\"productId\":\"${ING[ghee]}\",\"qtyPerYieldMilli\":50},{\"productId\":\"${ING[spice]}\",\"qtyPerYieldMilli\":30}]}"
recipe "$I_SEK" "{\"yieldQty\":1,\"ingredients\":[{\"productId\":\"${ING[beef]}\",\"qtyPerYieldMilli\":250},{\"productId\":\"${ING[spice]}\",\"qtyPerYieldMilli\":20}]}"
recipe "$I_NAN" "{\"yieldQty\":1,\"ingredients\":[{\"productId\":\"${ING[flour]}\",\"qtyPerYieldMilli\":150},{\"productId\":\"${ING[ghee]}\",\"qtyPerYieldMilli\":20}]}"
recipe "$I_CHA" "{\"yieldQty\":1,\"ingredients\":[{\"productId\":\"${ING[tea]}\",\"qtyPerYieldMilli\":20}]}"

# ── 6. floor: areas + tables ─────────────────────────────────────────────────
say "floor plan"
MAIN=$(post restaurant/areas '{"name":"Main Hall","kind":"INDOOR"}' | idof)
TERR=$(post restaurant/areas '{"name":"Terrace","kind":"TERRACE"}' | idof)
table() { post restaurant/tables "{\"areaId\":\"$1\",\"code\":\"$2\",\"capacity\":$3,\"shape\":\"$4\",\"posX\":$5,\"posY\":$6,\"width\":$7,\"height\":$8}" | idof; }
T1=$(table "$MAIN" T1 4 RECT 24 24 88 64); table "$MAIN" T2 2 ROUND 150 28 60 60 >/dev/null
table "$MAIN" T3 6 RECT 250 20 120 70 >/dev/null; T4=$(table "$MAIN" T4 4 RECT 410 24 88 64)
table "$TERR" P1 2 ROUND 40 140 60 60 >/dev/null; table "$TERR" P2 4 ROUND 150 135 78 78 >/dev/null
T7=$(table "$TERR" P3 8 RECT 270 135 150 78)

# ── 7. reservations + a few live orders ──────────────────────────────────────
say "reservations + sample orders"
post restaurant/reservations "{\"guestName\":\"Ayesha Khan\",\"guestPhone\":\"+92 300 1234567\",\"partySize\":6,\"reservedFor\":\"2026-08-01T20:00:00.000Z\"}" >/dev/null
post restaurant/reservations "{\"guestName\":\"Usman Ali\",\"partySize\":4,\"waitlist\":true,\"reservedFor\":\"2026-08-01T20:30:00.000Z\"}" >/dev/null
mkorder() { # tableId items_json
  local oid; oid=$(post restaurant/orders "{\"channel\":\"DINE_IN\",\"tableId\":\"$1\",\"guestCount\":2}" | idof)
  post "restaurant/orders/$oid/items" "$2" >/dev/null
  post "restaurant/orders/$oid/place" '{}' >/dev/null
  echo "$oid"
}
O1=$(mkorder "$T1" "{\"items\":[{\"itemId\":\"$I_KAR\",\"qty\":1},{\"itemId\":\"$I_NAN\",\"qty\":2},{\"itemId\":\"$I_CHA\",\"qty\":2}]}")
mkorder "$T7" "{\"items\":[{\"itemId\":\"$I_NIH\",\"qty\":3},{\"itemId\":\"$I_TIK\",\"qty\":2}]}" >/dev/null
# settle one so revenue + COGS + a GL journal exist
TOT=$(curl -s "$API_URL/restaurant/orders" -H "$H" | python3 -c "import sys,json;print([o['total']['amountMinor'] for o in json.load(sys.stdin)['data'] if o['id']=='$O1'][0])")
post "restaurant/orders/$O1/settle" "{\"payments\":[{\"method\":\"CASH\",\"amountMinor\":$TOT}]}" >/dev/null

# ── 8. multi-branch (multi-outlet) demo ──────────────────────────────────────
# One tenant, several physical outlets. Each branch gets its own restaurant_config
# (cloned from head office on provision), its own floor + orders/KDS. The menu and
# recipes above stay shared across all branches.
say "branches (outlets) + per-branch config"
branch() { post branches "$1" | idof; }
BR_GLB=$(branch '{"name":"Karahi Point — Gulberg","code":"KP-GLB","city":"Lahore","isHeadOffice":true}')
BR_DHA=$(branch '{"name":"Karahi Point — DHA","code":"KP-DHA","city":"Lahore"}')
# Provision each outlet's config (clones head-office warehouse + PKR + 16% tax so it can trade).
for BR in "$BR_GLB" "$BR_DHA"; do
  [ -n "$BR" ] && post "restaurant/branches/$BR/provision" '{}' >/dev/null
done
# DHA adds a 5% service charge — proves configuration is per-branch, not tenant-wide.
[ -n "$BR_DHA" ] && put restaurant/config "{\"branchId\":\"$BR_DHA\",\"serviceChargeBp\":500}" >/dev/null

# Branch-scoped floor + one live order per outlet (proves branch isolation of tables/orders/KDS).
barea()  { post restaurant/areas  "{\"name\":\"$2\",\"kind\":\"INDOOR\",\"branchId\":\"$1\"}" | idof; }
btable() { post restaurant/tables "{\"areaId\":\"$2\",\"branchId\":\"$1\",\"code\":\"$3\",\"capacity\":$4,\"shape\":\"RECT\",\"posX\":$5,\"posY\":24,\"width\":88,\"height\":64}" | idof; }
border() { # branchId tableId mainItemId
  local oid; oid=$(post restaurant/orders "{\"channel\":\"DINE_IN\",\"branchId\":\"$1\",\"tableId\":\"$2\",\"guestCount\":2}" | idof)
  post "restaurant/orders/$oid/items" "{\"items\":[{\"itemId\":\"$3\",\"qty\":1},{\"itemId\":\"$I_NAN\",\"qty\":2}]}" >/dev/null
  post "restaurant/orders/$oid/place" '{}' >/dev/null
}
if [ -n "$BR_GLB" ]; then
  GA=$(barea "$BR_GLB" "Gulberg Hall"); GT=$(btable "$BR_GLB" "$GA" G1 4 24); btable "$BR_GLB" "$GA" G2 2 150 >/dev/null
  border "$BR_GLB" "$GT" "$I_KAR"
fi
if [ -n "$BR_DHA" ]; then
  DA=$(barea "$BR_DHA" "DHA Hall"); DT=$(btable "$BR_DHA" "$DA" D1 6 24); btable "$BR_DHA" "$DA" D2 4 150 >/dev/null
  border "$BR_DHA" "$DT" "$I_NIH"
fi
say "2 outlets seeded: Gulberg (HQ) + DHA — each with its own floor + live order"


# ── 9. peripherals: receipt/kitchen printers + table QR stickers ──────────────
say "printers (till + kitchen stations) and table QR codes"
printer() { # key name kind connection host station charsPerLine [branchId]
  local body="{\"key\":\"$1\",\"name\":\"$2\",\"kind\":\"$3\",\"connection\":\"$4\",\"host\":\"$5\",\"charsPerLine\":$7"
  [ -n "$6" ] && body="$body,\"stationKey\":\"$6\""
  [ -n "${8:-}" ] && body="$body,\"branchId\":\"$8\""
  post restaurant/printers "$body}" | idof
}
# The till prints guest bills and kicks the cash drawer; each hot station gets its own KOT printer.
P_TILL=$(printer till-1 "Front Till (80mm)" RECEIPT NETWORK 192.168.1.50 "" 42)
[ -n "$P_TILL" ] && patch "restaurant/printers/$P_TILL" '{"cashDrawer":true,"isDefault":true}' >/dev/null
printer kitchen-hot "Hot Kitchen" KITCHEN NETWORK 192.168.1.51 HOT_KITCHEN 32 >/dev/null
printer kitchen-grill "Grill" KITCHEN NETWORK 192.168.1.52 GRILL 32 >/dev/null
printer kitchen-tandoor "Tandoor" KITCHEN NETWORK 192.168.1.53 TANDOOR 32 >/dev/null

# Receipt branding + auto-print behaviour (KOTs fire automatically; bills print on demand at the till).
# Config is PER BRANCH, and the outlets above were already provisioned from the head-office template —
# so apply the branding to each of them as well, not just the head-office row.
BRANDING='{"autoPrintKot":true,"autoPrintBill":false,"receiptFooter":"Shukriya! Aap ka din acha guzray.","taxNumber":"1234567-8"}'
put restaurant/config "$BRANDING" >/dev/null
for BR in "$BR_GLB" "$BR_DHA"; do
  [ -n "$BR" ] && put restaurant/config "$(python3 -c "import json,sys;d=json.loads(sys.argv[1]);d['branchId']=sys.argv[2];print(json.dumps(d))" "$BRANDING" "$BR")" >/dev/null
done

# Issue a QR sticker for every table — scanning one opens that table's tab.
for T in "$T1" "$T4" "$T7"; do [ -n "$T" ] && get "restaurant/tables/$T/qr" >/dev/null; done
say "printers registered (run scripts/print-agent.js on the till to actually print)"

say "done. Login at the web console or apps with:  $ADMIN_EMAIL / $ADMIN_PW"
