#!/bin/bash

# Alerts when a systemd unit is not active, and once more when it recovers.
#
# vars_logging.sh is deliberately not sourced: this runs at a short cron cadence and
# would otherwise leave dozens of log files a day in ~/server_scripts_logs.

script_dir="$(dirname "$(readlink -f "$0")")"

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <service>"
    exit 1
fi

SERVICE="$1"

STATE_DIR="$HOME/server_scripts_logs"
"$script_dir/create_logs_dir.sh" >/dev/null

# Does not end in .log, so clean_script_logs_older_n_days.sh leaves it alone
DOWN_MARKER="$STATE_DIR/service-status.$(printf '%s' "$SERVICE" | tr -c '[:alnum:]._-' '_').down"

alert() {
    "$script_dir/send_telegram_alert.sh" "$1"
}

if ! command -v systemctl >/dev/null 2>&1; then
    alert "$(hostname) Warning:\n\nsystemctl is not available, service status is not being monitored."
    exit 3
fi

# LoadState tells a wrong unit name apart from a genuinely stopped unit: is-active
# reports both as "inactive"
LOAD_STATE=$(systemctl show "$SERVICE" --property=LoadState --value 2>/dev/null)
ACTIVE_STATE=$(systemctl is-active "$SERVICE" 2>/dev/null)

if [ "$LOAD_STATE" != "loaded" ]; then
    # Throttled with a marker file, otherwise a lasting failure alerts on every run
    if [ ! -f "$DOWN_MARKER" ]; then
        alert "$(hostname) Warning:\n\n$SERVICE is not a known systemd unit (LoadState: ${LOAD_STATE:-unknown}). Verify the unit name with \"systemctl list-units\" after any OS upgrade."
        touch "$DOWN_MARKER"
    fi
    echo "$SERVICE is not a known unit."
    exit 2
fi

if [ "$ACTIVE_STATE" = "active" ]; then
    # Only alerts when the unit was previously marked down, so a healthy run stays quiet
    if [ -f "$DOWN_MARKER" ]; then
        alert "$(hostname) $SERVICE is active again."
        rm -f "$DOWN_MARKER"
    fi
    echo "$SERVICE is active."
    exit 0
fi

if [ ! -f "$DOWN_MARKER" ]; then
    DETAILS=$(systemctl show "$SERVICE" -p ActiveState -p SubState -p Result -p ExecMainStatus -p ActiveEnterTimestamp 2>&1)
    # Only root and members of adm / systemd-journal can read these, so they are an
    # addition to the properties above rather than the sole content of the alert
    LOGS=$(journalctl -u "$SERVICE" -n 10 --no-pager -o short-iso 2>/dev/null)
    # Truncated because Telegram rejects messages over 4096 characters
    [ -n "$LOGS" ] && DETAILS="$DETAILS\n\n$(printf '%s\n' "$LOGS" | tail -n 10)"
    alert "$(hostname) Warning:\n\n$SERVICE is ${ACTIVE_STATE:-unknown}.\n\n$DETAILS"
    touch "$DOWN_MARKER"
fi

echo "$SERVICE is ${ACTIVE_STATE:-unknown}."
exit 3
