#!/usr/bin/env bash
set -u

# Authorized security/observability simulation for staging or lab systems only.
# The script generates controlled HTTP events for EFK dashboards and Jira rules.

API="${API:-}"
MODE="${1:-light}"
CONFIRM="${2:-}"
SLEEP_SECONDS="${SLEEP_SECONDS:-0.2}"
AUTH_ATTEMPTS="${AUTH_ATTEMPTS:-30}"
RATE_REQUESTS="${RATE_REQUESTS:-150}"
CONNECT_TIMEOUT="${CONNECT_TIMEOUT:-5}"
MAX_TIME="${MAX_TIME:-15}"

usage() {
  cat <<'USAGE'
Usage:
  API=https://api.example.com ./deployment/security/attack-sim.sh <mode> --confirm-authorized

Modes:
  light      Run a small mixed simulation for EFK/Jira smoke testing.
  recon      Probe common discovery paths such as /api-docs, /.env, /admin.
  auth       Simulate failed login and email verification attempts.
  search     Send suspicious search payloads and regex-stress inputs.
  products   Fuzz product/recommendation endpoints with malformed IDs.
  checkout   Submit invalid checkout payloads to generate validation logs.
  rate       Create a short request spike against /api/products.
  all        Run every mode except rate.

Environment:
  API             Required base URL, for example https://api.fusion-electronics.com
  SLEEP_SECONDS   Delay between sequential requests. Default: 0.2
  AUTH_ATTEMPTS   Failed login attempts for auth mode. Default: 30
  RATE_REQUESTS   Parallel requests for rate mode. Default: 150

Examples:
  API=https://api.fusion-electronics.com ./deployment/security/attack-sim.sh light --confirm-authorized
  API=https://api.fusion-electronics.com AUTH_ATTEMPTS=20 ./deployment/security/attack-sim.sh auth --confirm-authorized
  API=https://api.fusion-electronics.com RATE_REQUESTS=80 ./deployment/security/attack-sim.sh rate --confirm-authorized
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
      -H "User-Agent: fusion-attack-sim/1.0" \
      -d "$body" || true)"
  else
    code="$(curl -sS -o /dev/null -w "%{http_code}" \
      --connect-timeout "$CONNECT_TIMEOUT" \
      --max-time "$MAX_TIME" \
      -X "$method" "$API$path" \
      -H "User-Agent: fusion-attack-sim/1.0" || true)"
  fi

  printf '%s -> HTTP %s\n' "$label" "$code"
  sleep "$SLEEP_SECONDS"
}

run_recon() {
  echo "== recon: discovery and suspicious path probes =="
  request GET "/"
  request GET "/api-docs"
  request GET "/api-docs/swagger.json"
  request GET "/.env"
  request GET "/admin"
  request GET "/api/users"
  request GET "/wp-admin"
}

run_auth() {
  echo "== auth: failed login and user-enumeration simulation =="

  local i
  for i in $(seq 1 "$AUTH_ATTEMPTS"); do
    request POST "/api/auth/login" \
      "{\"email\":\"victim$i@example.com\",\"password\":\"WrongPass123\"}" \
      "login failure $i/$AUTH_ATTEMPTS"
  done

  request POST "/api/auth/login" \
    '{"email":"not-an-email","password":"x"}' \
    "login validation error"

  request POST "/api/auth/verify-email" \
    '{"email":"admin@example.com"}' \
    "verify-email admin@example.com"

  request POST "/api/auth/verify-email" \
    '{"email":"unknown@example.com"}' \
    "verify-email unknown@example.com"
}

run_search() {
  echo "== search: suspicious query and regex-stress payloads =="
  request GET "/api/search?q=.*"
  request GET "/api/search?q=%5Ba-"
  request GET "/api/search?q=%28a%2B%29%2B%24"
  request GET "/api/search?q=%24ne"
  request GET "/api/search?q=%7B%22%24gt%22%3A%22%22%7D"
  request GET "/api/search?q=%3Cscript%3Ealert%281%29%3C%2Fscript%3E"
}

run_products() {
  echo "== products: ID fuzzing and recommendation abuse =="
  request GET "/api/products/not-an-object-id"
  request GET "/api/products/not-an-object-id/similar"
  request GET "/api/products/000000000000000000000000"
  request GET "/api/products/000000000000000000000000/similar"

  request POST "/api/products/recommendations" '{}' "recommendations empty object"
  request POST "/api/products/recommendations" '{"ids":[]}' "recommendations empty ids"
  request POST "/api/products/recommendations" \
    '{"ids":["not-an-object-id","also-bad"]}' \
    "recommendations malformed ids"
}

run_checkout() {
  echo "== checkout: invalid order and card-validation probes =="
  request POST "/api/checkout/create-order" '{}' "checkout missing fields"

  request POST "/api/checkout/create-order" \
    '{"items":[{"productId":"not-an-object-id","quantity":1}],"name":"Test Buyer","email":"bad-email","shippingAddress":"Lab","cardNumber":"411111","cardName":"Test Buyer","expiry":"99/99","cvc":"12"}' \
    "checkout invalid email/card/product"

  request POST "/api/checkout/create-order" \
    '{"items":[{"productId":"000000000000000000000000","quantity":1}],"name":"Test Buyer","email":"buyer@example.com","shippingAddress":"Lab","cardNumber":"4111111111111111","cardName":"Test Buyer","expiry":"12/30","cvc":"123"}' \
    "checkout unavailable product"
}

run_rate() {
  echo "== rate: short request spike against /api/products =="
  echo "starting $RATE_REQUESTS parallel requests"

  local i
  for i in $(seq 1 "$RATE_REQUESTS"); do
    curl -sS -o /dev/null -w "rate request $i -> HTTP %{http_code}\n" \
      --connect-timeout "$CONNECT_TIMEOUT" \
      --max-time "$MAX_TIME" \
      "$API/api/products" \
      -H "User-Agent: fusion-attack-sim/1.0" &
  done

  wait
}

run_light() {
  echo "== light: mixed low-volume smoke simulation =="
  run_recon
  run_search
  run_products
  run_checkout

  local original_attempts="$AUTH_ATTEMPTS"
  AUTH_ATTEMPTS=5
  run_auth
  AUTH_ATTEMPTS="$original_attempts"
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
    recon) run_recon ;;
    auth) run_auth ;;
    search) run_search ;;
    products) run_products ;;
    checkout) run_checkout ;;
    rate) run_rate ;;
    all)
      run_recon
      run_auth
      run_search
      run_products
      run_checkout
      ;;
    *)
      usage
      die "unknown mode: $MODE"
      ;;
  esac
}

main "$@"
