#!/usr/bin/env bash
# Starts a leaderboard rescan of SERVER_URL, waits for it to finish, and reports the score.
set -uo pipefail

api="${API_URL%/}/api/v1/public/catalog"
out="${GITHUB_OUTPUT:-/dev/null}"
summary="${GITHUB_STEP_SUMMARY:-/dev/null}"

finish() {
  # $1: annotation level for a problem, $2: message
  if [ "$FAIL_ON_ERROR" = "true" ]; then
    echo "::error::$2"
    exit 1
  fi
  echo "::$1::$2"
  exit 0
}

if [ -z "${MANUFACT_API_KEY:-}" ]; then
  finish warning "Manufact Leaderboard: api-key is empty. Add MANUFACT_API_KEY as a repository secret."
fi

body=$(jq -n --arg url "$SERVER_URL" '{url: $url}')
response=$(curl -sS -X POST "$api" \
  -H "x-api-key: $MANUFACT_API_KEY" \
  -H "content-type: application/json" \
  -d "$body" -w '\n%{http_code}') || finish warning "Manufact Leaderboard: could not reach $API_URL."
code=$(tail -n1 <<<"$response")
entry=$(sed '$d' <<<"$response")
if [ "$code" -ge 300 ]; then
  message=$(jq -r '.error // .message // empty' <<<"$entry" 2>/dev/null)
  finish warning "Manufact Leaderboard: the rescan did not start (HTTP $code). ${message}"
fi

slug=$(jq -r '.slug' <<<"$entry")
report="${SITE_URL%/}/leaderboard/$slug"
{
  echo "slug=$slug"
  echo "report-url=$report"
} >>"$out"

# Still running unless this rescan's review attempt already failed.
running() {
  jq -e '.reviewAttempt.status != "failed"
    and ([.audit.status, .documentationReview.status] | any(. == "pending" or . == "running"))' \
    <<<"$1" >/dev/null
}

status=started
if [ "$WAIT" = "true" ]; then
  echo "Rescan started: $report"
  deadline=$((SECONDS + TIMEOUT_MINUTES * 60))
  while running "$entry" && [ "$SECONDS" -lt "$deadline" ]; do
    sleep 10
    next=$(curl -fsS "$api/$slug") && entry=$next
  done
  if [ "$(jq -r '.reviewAttempt.status // empty' <<<"$entry")" = failed ]; then
    status=failed
  elif running "$entry"; then
    status=running
  else
    status=$(jq -r '.audit.status // "completed"' <<<"$entry")
  fi
fi

score=$(jq -r '.quality.score // empty' <<<"$entry")
{
  echo "status=$status"
  echo "score=$score"
} >>"$out"

case "$status" in
  completed)
    echo "Manufact score: ${score:-none}/100  $report"
    echo "### Manufact Leaderboard: ${score:-no score}/100 ([report]($report))" >>"$summary"
    ;;
  started)
    echo "Rescan started. The score updates on $report"
    echo "### Manufact Leaderboard: rescan started ([report]($report))" >>"$summary"
    ;;
  running)
    echo "### Manufact Leaderboard: still running after ${TIMEOUT_MINUTES} min ([report]($report))" >>"$summary"
    finish warning "Manufact Leaderboard: the rescan is still running after ${TIMEOUT_MINUTES} minutes. See $report"
    ;;
  *)
    error=$(jq -r '.reviewAttempt.error // .audit.errorMessage // empty' <<<"$entry")
    echo "### Manufact Leaderboard: rescan failed ([report]($report))" >>"$summary"
    finish warning "Manufact Leaderboard: the rescan failed. ${error} See $report"
    ;;
esac
