#!/bin/bash

# Alerts on every successful SSH login. Installed in root's crontab at "*/5 * * * *".
#
# vars_logging.sh is deliberately not sourced: it opens a new log file per run, which at
# this cadence would leave ~290 files a day in ~/server_scripts_logs.

script_dir="$(dirname "$(readlink -f "$0")")"

# Verify with "journalctl -u ssh.service | grep Accepted" after install; a wrong unit
# name here fails silently, with no alerts ever sent
SSH_UNIT="ssh.service"

STATE_DIR="$HOME/server_scripts_logs"
# Neither file ends in .log, so clean_script_logs_older_n_days.sh leaves them alone
CURSOR_FILE="$STATE_DIR/ssh-login-monitor.cursor"
ERROR_MARKER="$STATE_DIR/ssh-login-monitor.error"

"$script_dir/../lib/create_logs_dir.sh" >/dev/null

alert() {
    "$script_dir/../lib/send_telegram_alert.sh" "$1"
}

# Throttled with a marker file: a persistent journalctl failure would otherwise alert
# every 30 seconds
report_failure() {
    if [ ! -f "$ERROR_MARKER" ]; then
        alert "$(hostname) Warning:\n\nSSH login monitoring is broken, journalctl -u $SSH_UNIT failed:\n\n$1"
        touch "$ERROR_MARKER"
    fi
}

scan() {
    local cursor out new_cursor logins count

    cursor=$(cat "$CURSOR_FILE" 2>/dev/null)

    if [ -z "$cursor" ]; then
        # First run: record the current position instead of replaying the whole journal
        out=$(journalctl -u "$SSH_UNIT" -n 0 --show-cursor --no-pager 2>&1) || {
            report_failure "$out"
            return
        }
    else
        # Cursors survive log rotation and reboots, so each entry is reported exactly
        # once - a byte offset into /var/log/auth.log would not
        out=$(journalctl -u "$SSH_UNIT" --after-cursor "$cursor" --show-cursor --no-pager -o short-iso 2>&1) || {
            # A cursor the journal no longer holds would wedge the monitor forever
            report_failure "$out"
            rm -f "$CURSOR_FILE"
            return
        }
    fi

    rm -f "$ERROR_MARKER"

    new_cursor=$(printf '%s\n' "$out" | sed -n 's/^-- cursor: //p' | tail -n 1)
    if [ -n "$new_cursor" ]; then
        printf '%s\n' "$new_cursor" > "$CURSOR_FILE"
    fi

    if [ -z "$cursor" ]; then
        echo "First run, journal position recorded."
        return
    fi

    # Usernames reach the journal from the remote peer: drop control characters so a
    # crafted value cannot forge extra lines in the alert
    logins=$(printf '%s\n' "$out" \
        | grep -E 'Accepted (password|publickey|keyboard-interactive)' \
        | tr -d '\000-\010\013\014\016-\037')

    if [ -z "$logins" ]; then
        echo "No new SSH logins."
        return
    fi

    count=$(printf '%s\n' "$logins" | wc -l)
    # Truncated because Telegram rejects messages over 4096 characters
    alert "$(hostname) SSH login: $count successful login(s).\n\nMost recent:\n$(printf '%s\n' "$logins" | tail -n 20)"
}

scan
