#!/bin/bash

# Alerts when a website stops answering, answers with an error status, or serves a
# WordPress/PHP crash page, and once more when it recovers.
#
# vars_logging.sh is deliberately not sourced: this runs at a short cron cadence and
# would otherwise leave dozens of log files a day in ~/server_scripts_logs.

script_dir="$(dirname "$(readlink -f "$0")")"

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Usage: $0 <url> [expected_text]"
    exit 1
fi

URL="$1"
# Optional marker of a fully rendered page (e.g. the site title), so a 200 serving a
# blank or half-built page is still caught
EXPECTED_TEXT="$2"

TIMEOUT=20
ATTEMPTS=3
RETRY_DELAY=10

STATE_DIR="$HOME/server_scripts_logs"
"$script_dir/create_logs_dir.sh" >/dev/null

# Does not end in .log, so clean_script_logs_older_n_days.sh leaves it alone
DOWN_MARKER="$STATE_DIR/website-health.$(printf '%s' "$URL" | tr -c '[:alnum:]._-' '_').down"

alert() {
    "$script_dir/send_telegram_alert.sh" "$1"
}

if ! command -v curl >/dev/null 2>&1; then
    alert "$(hostname) Warning:\n\ncurl is not available, $URL is not being monitored."
    exit 3
fi

BODY_FILE=$(mktemp) || exit 3
CURL_ERR_FILE=$(mktemp) || exit 3
trap 'rm -f "$BODY_FILE" "$CURL_ERR_FILE"' EXIT

# What WordPress and PHP print when the site answers but is broken
CRASH_PATTERNS=(
    "There has been a critical error on this website"
    "Error establishing a database connection"
    "The site is experiencing technical difficulties"
    "Fatal error:"
    "Parse error:"
)

FAILURE=""

find_crash_text() {
    for PATTERN in "${CRASH_PATTERNS[@]}"; do
        if grep -q -i -F -- "$PATTERN" "$BODY_FILE"; then
            printf '%s' "$PATTERN"
            return 0
        fi
    done
    return 1
}

run_check() {
    FAILURE=""

    # -L so a http -> https redirect is followed, --compressed because the site serves gzip
    HTTP_CODE=$(curl -sS -L --compressed --max-time "$TIMEOUT" \
        -o "$BODY_FILE" -w '%{http_code}' "$URL" 2>"$CURL_ERR_FILE")
    CURL_EXIT=$?

    # Covers DNS failures, refused connections, TLS errors and timeouts
    if [ "$CURL_EXIT" -ne 0 ]; then
        FAILURE="the request failed (curl exit $CURL_EXIT): $(tr -d '\r' <"$CURL_ERR_FILE" | head -n 3)"
        return 1
    fi

    CRASH_TEXT=$(find_crash_text)

    # 5xx is the server failing, 4xx means the page is gone or blocked; both are wrong
    # for a site home page
    if [ "${HTTP_CODE:-0}" -ge 400 ] 2>/dev/null; then
        FAILURE="HTTP $HTTP_CODE was returned."
        [ -n "$CRASH_TEXT" ] && FAILURE="$FAILURE The page contains \"$CRASH_TEXT\"."
        return 1
    fi

    if [ -n "$CRASH_TEXT" ]; then
        FAILURE="HTTP $HTTP_CODE was returned, but the page contains \"$CRASH_TEXT\"."
        return 1
    fi

    if [ -n "$EXPECTED_TEXT" ] && ! grep -q -i -F -- "$EXPECTED_TEXT" "$BODY_FILE"; then
        FAILURE="HTTP $HTTP_CODE was returned, but the page does not contain the expected text \"$EXPECTED_TEXT\"."
        return 1
    fi

    return 0
}

# Retried before alerting, so a single timeout or a restart in progress does not page
HEALTHY=1
for ATTEMPT in $(seq 1 "$ATTEMPTS"); do
    if run_check; then
        HEALTHY=0
        break
    fi
    [ "$ATTEMPT" -lt "$ATTEMPTS" ] && sleep "$RETRY_DELAY"
done

if [ "$HEALTHY" -eq 0 ]; then
    # Only alerts when the site was previously marked down, so a healthy run stays quiet
    if [ -f "$DOWN_MARKER" ]; then
        alert "$(hostname) $URL is reachable again (HTTP $HTTP_CODE)."
        rm -f "$DOWN_MARKER"
    fi
    echo "$URL is up (HTTP $HTTP_CODE)."
    exit 0
fi

# Throttled with a marker file, otherwise a lasting outage alerts on every run
if [ ! -f "$DOWN_MARKER" ]; then
    # Truncated because Telegram rejects messages over 4096 characters
    SNIPPET=$(tr -d '\r' <"$BODY_FILE" | sed 's/<[^>]*>//g' | grep -v '^[[:space:]]*$' | head -c 800)
    DETAILS=""
    [ -n "$SNIPPET" ] && DETAILS="\n\nPage content:\n$SNIPPET"
    alert "$(hostname) Warning:\n\n$URL is down after $ATTEMPTS attempts: $FAILURE$DETAILS"
    touch "$DOWN_MARKER"
fi

echo "$URL is down: $FAILURE"
exit 3
