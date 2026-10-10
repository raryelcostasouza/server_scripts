#!/bin/bash

script_dir="$(dirname "$(readlink -f "$0")")"

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <max_age_days> <rclone_remote_path>"
    exit 1
fi

MAX_AGE_DAYS="$1"
REMOTE_PATH="$2"

# Validate the max age argument
if ! [[ "$MAX_AGE_DAYS" =~ ^[0-9]+$ ]] || [ "$MAX_AGE_DAYS" -lt 1 ]; then
    echo "Error: <max_age_days> must be an integer greater than 0."
    exit 1
fi

printf "\n\n"
echo "Checking freshness of $REMOTE_PATH"

# Modification times are listed as "YYYY-MM-DD HH:MM:SS.nnnnnnnnn", so a reverse
# lexicographic sort puts the newest file first
LAST_MODIFIED=$(rclone lsf --recursive --files-only --format "t" "$REMOTE_PATH" | sort -r | head -n 1)

if [ -z "$LAST_MODIFIED" ]; then
    $script_dir/send_telegram_alert.sh "$(hostname) Warning:\n\n No backup file found at $REMOTE_PATH, or the remote is unreachable."
    exit 2
fi

LAST_EPOCH=$(date -d "$LAST_MODIFIED" +%s)
AGE_DAYS=$(( ( $(date +%s) - LAST_EPOCH ) / 86400 ))

if [ "$AGE_DAYS" -gt "$MAX_AGE_DAYS" ]; then
    $script_dir/send_telegram_alert.sh "$(hostname) Warning:\n\n Newest backup at $REMOTE_PATH is $AGE_DAYS days old (limit: $MAX_AGE_DAYS days).\n\nLast backup: $LAST_MODIFIED"
    exit 3
fi

echo "Newest backup is $AGE_DAYS days old ($LAST_MODIFIED). No action needed."
exit 0
