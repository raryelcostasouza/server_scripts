#!/bin/bash

# Must match the cron cadence, otherwise bans are either missed or re-reported
days=7

# Determine the directory of the current script
script_dir="$(dirname "$(readlink -f "$0")")"

# Source the vars_logging.sh script for logging functions
source "$script_dir/../lib/vars_logging.sh"

LOG_FILE="/var/log/fail2ban.log"

END_DATE=$(date "+%Y-%m-%d")
START_DATE=$(date -d "$END_DATE -$days days" "+%Y-%m-%d")

if [ ! -r "$LOG_FILE" ]; then
    $script_dir/../lib/send_telegram_alert.sh "$(hostname) Warning:\n\n$LOG_FILE is missing or not readable, fail2ban bans are not being monitored."
    exit 1
fi

# Restricted to the window so the whole ban history is not resent on every run
new_bans=$(awk -v start="$START_DATE" -v end="$END_DATE" '
    $0 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}/ {
        log_date = substr($0, 1, 10)
        if (log_date >= start && log_date <= end) {
            print
        }
    }
' "$LOG_FILE" | grep -E '\] Ban ')

if [ -n "$new_bans" ]; then
    ban_count=$(echo "$new_bans" | wc -l)
    # Truncated because Telegram rejects messages over 4096 characters
    MESSAGE="$(hostname) fail2ban: $ban_count ban(s) from $START_DATE to $END_DATE.\n\nMost recent:\n$(echo "$new_bans" | tail -n 20)"
    $script_dir/../lib/send_telegram_alert.sh "$MESSAGE"
else
    echo "No bans between $START_DATE and $END_DATE."
fi

# Check if the error log file is not empty (if applicable)
$script_dir/../lib/check_if_error_log_not_empty.sh "$ERROR_LOG_FILE"