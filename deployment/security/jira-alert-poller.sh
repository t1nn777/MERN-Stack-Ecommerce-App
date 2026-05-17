#!/usr/bin/env bash
set -u

# Poll Elasticsearch for suspicious log patterns and forward summarized alerts
# to Jira Automation Incoming Webhook. This avoids Kibana paid webhook connectors.
#
# Required:
#   ES_URL=http://192.168.1.138:9200
#   JIRA_WEBHOOK_URL=https://api-private.atlassian.com/automation/webhooks/jira/a/...
#   JIRA_WEBHOOK_TOKEN=...
#
# Optional:
#   ES_INDEX_PATTERN=kubernetes-logs*
#   LOOKBACK_MINUTES=5
#   STATE_FILE=/tmp/fusion-jira-alert-poller.state
#   KIBANA_URL=http://192.168.1.138:5601

ES_URL="${ES_URL:-http://localhost:9200}"
ES_INDEX_PATTERN="${ES_INDEX_PATTERN:-kubernetes-logs*}"
JIRA_WEBHOOK_URL="${JIRA_WEBHOOK_URL:-}"
JIRA_WEBHOOK_TOKEN="${JIRA_WEBHOOK_TOKEN:-}"
LOOKBACK_MINUTES="${LOOKBACK_MINUTES:-5}"
STATE_FILE="${STATE_FILE:-/tmp/fusion-jira-alert-poller.state}"
KIBANA_URL="${KIBANA_URL:-http://localhost:5601}"
MAX_ALERTS_PER_RUN="${MAX_ALERTS_PER_RUN:-10}"
CURL_CONNECT_TIMEOUT="${CURL_CONNECT_TIMEOUT:-5}"
CURL_MAX_TIME="${CURL_MAX_TIME:-20}"

usage() {
  cat <<'USAGE'
Usage:
  ES_URL=http://192.168.1.138:9200 \
  ES_INDEX_PATTERN='kubernetes-logs*' \
  JIRA_WEBHOOK_URL='https://api-private.atlassian.com/automation/webhooks/jira/a/...' \
  JIRA_WEBHOOK_TOKEN='jira-webhook-secret' \
  ./deployment/security/jira-alert-poller.sh

The script queries Elasticsearch for recent attack-simulation log patterns and
sends one Jira webhook event per matched rule. It stores a small local state
file to avoid repeatedly sending the same rule in the same time bucket.

Required tools:
  curl, jq
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_tools() {
  command -v curl >/dev/null 2>&1 || die "curl is required"
  command -v jq >/dev/null 2>&1 || die "jq is required. Install with: sudo apt install -y jq"
}

require_config() {
  [ -n "$JIRA_WEBHOOK_URL" ] || die "JIRA_WEBHOOK_URL is required"
  [ -n "$JIRA_WEBHOOK_TOKEN" ] || die "JIRA_WEBHOOK_TOKEN is required"
}

json_escape() {
  jq -Rn --arg value "$1" '$value'
}

time_bucket() {
  date -u +"%Y-%m-%dT%H:%M"
}

already_sent() {
  local key="$1"
  [ -f "$STATE_FILE" ] && grep -Fxq "$key" "$STATE_FILE"
}

mark_sent() {
  local key="$1"
  mkdir -p "$(dirname "$STATE_FILE")"
  printf '%s\n' "$key" >> "$STATE_FILE"
  tail -n 500 "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
}

query_count() {
  local kql="$1"

  curl -sS "${ES_URL}/${ES_INDEX_PATTERN}/_search" \
    --connect-timeout "$CURL_CONNECT_TIMEOUT" \
    --max-time "$CURL_MAX_TIME" \
    -H "Content-Type: application/json" \
    -d "{
      \"size\": 1,
      \"sort\": [{ \"@timestamp\": { \"order\": \"desc\", \"unmapped_type\": \"date\" } }],
      \"query\": {
        \"bool\": {
          \"filter\": [
            {
              \"range\": {
                \"@timestamp\": {
                  \"gte\": \"now-${LOOKBACK_MINUTES}m\",
                  \"lte\": \"now\"
                }
              }
            },
            {
              \"query_string\": {
                \"query\": ${kql},
                \"fields\": [\"message\", \"log\"],
                \"analyze_wildcard\": true
              }
            }
          ]
        }
      }
    }"
}

send_jira() {
  local attack_type="$1"
  local severity="$2"
  local endpoint="$3"
  local status_code="$4"
  local user_agent="$5"
  local log_sample="$6"
  local count="$7"

  local payload
  payload="$(jq -n \
    --arg attack_type "$attack_type" \
    --arg severity "$severity" \
    --arg source_ip "unknown" \
    --arg endpoint "$endpoint" \
    --arg status_code "$status_code" \
    --arg user_agent "$user_agent" \
    --arg time_window "${LOOKBACK_MINUTES} minutes" \
    --arg log_sample "$log_sample (matches: $count)" \
    --arg kibana_url "$KIBANA_URL" \
    '{
      attack_type: $attack_type,
      severity: $severity,
      source_ip: $source_ip,
      endpoint: $endpoint,
      status_code: $status_code,
      user_agent: $user_agent,
      time_window: $time_window,
      log_sample: $log_sample,
      kibana_url: $kibana_url
    }')"

  curl -sS -o /dev/null -w "%{http_code}" \
    --connect-timeout "$CURL_CONNECT_TIMEOUT" \
    --max-time "$CURL_MAX_TIME" \
    -X POST "$JIRA_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -H "X-Automation-Webhook-Token: ${JIRA_WEBHOOK_TOKEN}" \
    -d "$payload"
}

check_rule() {
  local rule_id="$1"
  local attack_type="$2"
  local severity="$3"
  local endpoint="$4"
  local status_code="$5"
  local user_agent="$6"
  local query="$7"
  local threshold="$8"
  local sample="$9"

  local escaped_query result count key http_code
  escaped_query="$(json_escape "$query")"
  result="$(query_count "$escaped_query")"
  count="$(printf '%s' "$result" | jq -r '.hits.total.value // 0')"

  if [ "$count" -lt "$threshold" ]; then
    printf '%s: %s matches, below threshold %s\n' "$rule_id" "$count" "$threshold"
    return 0
  fi

  key="$(time_bucket):${rule_id}"
  if already_sent "$key"; then
    printf '%s: %s matches, already sent for current time bucket\n' "$rule_id" "$count"
    return 0
  fi

  http_code="$(send_jira "$attack_type" "$severity" "$endpoint" "$status_code" "$user_agent" "$sample" "$count")"
  printf '%s: %s matches, Jira HTTP %s\n' "$rule_id" "$count" "$http_code"

  case "$http_code" in
    200|201|202|204) mark_sent "$key" ;;
    *) return 1 ;;
  esac
}

main() {
  if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
  fi

  require_tools
  require_config

  check_rule \
    "recon" \
    "Reconnaissance" \
    "Medium" \
    "Sensitive path probing" \
    "404/405" \
    "fusion-attack-sim/1.0" \
    '"/.env" OR "/admin" OR "/wp-admin" OR "/api-docs/swagger.json"' \
    1 \
    "Sensitive endpoint probing detected"

  check_rule \
    "brute-force-login" \
    "Brute Force Login" \
    "High" \
    "/api/auth/login" \
    "400/405" \
    "fusion-attack-sim/1.0" \
    '"/api/auth/login" AND ("400" OR "405" OR "Invalid credentials")' \
    10 \
    "Multiple failed login attempts detected"

  check_rule \
    "search-injection" \
    "Search Injection" \
    "High" \
    "/api/search" \
    "400/500" \
    "fusion-injection-sim/1.0" \
    '"/api/search" AND ("$ne" OR "$gt" OR "$regex" OR "%24ne" OR "%24gt" OR "%24regex" OR " ne " OR " gt " OR " regex " OR "<script>" OR "UNION SELECT" OR "DROP TABLE")' \
    1 \
    "Suspicious search payload detected"

  check_rule \
    "nosql-injection" \
    "NoSQL Injection" \
    "High" \
    "MongoDB-backed API" \
    "400/500" \
    "fusion-injection-sim/1.0" \
    '"$ne" OR "$gt" OR "$regex" OR "$where" OR "%24ne" OR "%24gt" OR "%24regex" OR "%24where" OR " ne " OR " gt " OR " regex " OR " where " OR "NoSQL injection"' \
    1 \
    "MongoDB operator pattern detected in request logs"

  check_rule \
    "product-id-fuzzing" \
    "Product ID Fuzzing" \
    "Medium" \
    "/api/products/*" \
    "404/500" \
    "fusion-attack-sim/1.0" \
    '"/api/products" AND ("not-an-object-id" OR "CastError" OR "404" OR "500")' \
    5 \
    "Malformed product ID activity detected"

  check_rule \
    "checkout-abuse" \
    "Checkout Abuse" \
    "High" \
    "/api/checkout/create-order" \
    "400" \
    "fusion-attack-sim/1.0" \
    '"/api/checkout/create-order" AND ("400" OR "Invalid card" OR "Invalid CVC" OR "Missing required fields")' \
    5 \
    "Multiple checkout validation failures detected"
}

main "$@"
