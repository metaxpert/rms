#!/usr/bin/env bash
#
# Create (or reset) a platform SUPER_ADMIN — the operator account that can
# provision companies.
#
# Why this exists as its own script: seed-demo.sh only bootstraps a super-admin
# on the branch where it also creates the demo tenant. Re-run it against a server
# that already has `chef@karahipoint.test` and it takes the "reusing the tenant"
# path and never creates one — which is exactly what happened on the live server,
# leaving no account able to reach /platform/companies.
#
# This is the insert DEPLOYMENT.md §4.5 points at ("the seed script shows the
# exact SQL insert with a hashed password"), lifted out so it can be run on its
# own, idempotently, without re-seeding anything.
#
#   bash scripts/create-superadmin.sh sa@metaxperts.net 'a-strong-password'
#
# Env overrides:
#   ERP_DIR     where the ERP checkout is (for argon2)   default ~/erp
#   PG_CONTAINER  postgres container name                default metaxperts-erp-prod-postgres-1
#   PG_USER / PG_DB                                      default metaxperts / metaxperts
#   API_URL     used only to verify the login afterwards  default https://rms.metaxperts.net/api
#   OWNER_URL   if set, psql is used directly instead of docker exec
#
# This account can create and configure EVERY company on the server. On a
# public host that is not a demo credential — pick a real password.

set -uo pipefail

EMAIL="${1:-}"
PASSWORD="${2:-}"
ERP_DIR="${ERP_DIR:-$HOME/erp}"
PG_CONTAINER="${PG_CONTAINER:-metaxperts-erp-prod-postgres-1}"
PG_USER="${PG_USER:-metaxperts}"
PG_DB="${PG_DB:-metaxperts}"
API_URL="${API_URL:-https://rms.metaxperts.net/api}"
PLATFORM_TENANT="${PLATFORM_TENANT:-11111111-1111-1111-1111-111111111111}"

die() { printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }
say() { printf '\033[1;33m[sa]\033[0m %s\n' "$*"; }

[ -n "$EMAIL" ] && [ -n "$PASSWORD" ] || die \
"usage: bash scripts/create-superadmin.sh <email> <password>

  e.g. bash scripts/create-superadmin.sh sa@metaxperts.net 'pick-something-strong'

This account can configure every company on the server, so it is not somewhere
to reuse a demo password."

case "$PASSWORD" in
  SuperAdmin123!|Password123!|admin|changeme|ChangeMe123!)
    say "WARNING: '$PASSWORD' is a well-known default, and rms.metaxperts.net is"
    say "         reachable from the internet. Continuing in 5s — Ctrl-C to stop."
    sleep 5 ;;
esac
[ "${#PASSWORD}" -ge 12 ] || say "note: shorter than 12 characters."

# ── the password hash ────────────────────────────────────────────────────────
# argon2 is a native module, so it is used from the ERP's own node_modules
# rather than installed here; the API verifies against whatever argon2 wrote.
[ -d "$ERP_DIR/node_modules/argon2" ] || die \
  "argon2 not found under $ERP_DIR/node_modules. Set ERP_DIR to the ERP checkout."

say "hashing"
HASH="$(cd "$ERP_DIR" && PW="$PASSWORD" node -e \
  "require('argon2').hash(process.env.PW).then(h=>process.stdout.write(h))" 2>/dev/null)"
[ -n "$HASH" ] || die "argon2 hashing failed (is $ERP_DIR/node_modules complete?)"

# ── the insert ───────────────────────────────────────────────────────────────
# Upsert, so re-running resets the password rather than failing, and so an
# account demoted by hand gets SUPER_ADMIN back.
SQL="INSERT INTO users (tenant_id, email, password_hash, is_active, roles)
VALUES ('$PLATFORM_TENANT', '$EMAIL', '$HASH', true, '{SUPER_ADMIN}')
ON CONFLICT (lower(email)) DO UPDATE
   SET password_hash = EXCLUDED.password_hash,
       is_active     = true,
       roles         = '{SUPER_ADMIN}';"

say "writing $EMAIL to the users table"
if [ -n "${OWNER_URL:-}" ]; then
  command -v psql >/dev/null || die "OWNER_URL is set but psql is not installed."
  printf '%s\n' "$SQL" | psql "$OWNER_URL" -v ON_ERROR_STOP=1 -q || die "the insert failed."
else
  # `sg docker` because the docker group is typically not in the login session's
  # group set on this host.
  DOCKER="docker"; command -v docker >/dev/null || die "docker not found."
  printf '%s\n' "$SQL" | sg docker -c \
    "$DOCKER exec -i $PG_CONTAINER psql -U $PG_USER -d $PG_DB -v ON_ERROR_STOP=1 -q" \
    || die "the insert failed. If the container or role differs, set PG_CONTAINER/PG_USER/PG_DB, or OWNER_URL."
fi

# ── prove it ─────────────────────────────────────────────────────────────────
# A row in a table is not the same as an account that can sign in: the API has
# to accept the hash, and the token has to actually carry SUPER_ADMIN.
say "verifying against $API_URL"
TOKEN="$(curl -s --max-time 20 -X POST "$API_URL/auth/login" \
  -H 'content-type: application/json' \
  --data-binary "$(EMAIL="$EMAIL" PW="$PASSWORD" python3 -c \
     'import json,os; print(json.dumps({"email":os.environ["EMAIL"],"password":os.environ["PW"]}))')" \
  | python3 -c 'import sys,json
try: print(json.load(sys.stdin)["data"]["accessToken"])
except Exception: print("")')"

[ -n "$TOKEN" ] || die "the row was written but login failed — the API rejected the credentials."

ROLES="$(printf '%s' "$TOKEN" | python3 -c 'import sys,base64,json
p=sys.stdin.read().split(".")[1]; p+="="*(-len(p)%4)
print(",".join(json.loads(base64.urlsafe_b64decode(p)).get("roles",[])))')"
say "login OK — roles: $ROLES"
case "$ROLES" in *SUPER_ADMIN*) ;; *) die "the token does not carry SUPER_ADMIN." ;; esac

CODE="$(curl -s -o /dev/null --max-time 20 -w '%{http_code}' \
  -H "authorization: Bearer $TOKEN" "$API_URL/tenants")"
[ "$CODE" = "200" ] || die "GET /tenants returned $CODE — the role is not being honoured."

printf '\n\033[32m%s\033[0m\n' "Done. $EMAIL is a platform super-admin."
cat <<EOF

Sign in at the web console and the sidebar will now show Platform → Companies:

  https://rms.metaxperts.net/login
  → https://rms.metaxperts.net/platform/companies

"New company" creates the company, its first admin user and its feature plan in
one step. For a standalone RMS, give it the starter plan and switch on only
'restaurant' — every other module is then hidden and the API refuses it.

Keep these credentials safe: this account can configure every company here.
EOF
