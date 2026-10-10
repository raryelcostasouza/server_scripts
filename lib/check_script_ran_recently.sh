#!/bin/bash

script_dir="$(dirname "$(readlink -f "$0")")"

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <max_age_days> <script_name>"
    exit 1
fi

MAX_AGE_DAYS="$1"
SCRIPT_NAME="$2"
LOGS_DIR="$HOME/server_scripts_logs"

# Validate the max age argument
if ! [[ "$MAX_AGE_DAYS" =~ ^[0-9]+$ ]] || [ "$MAX_AGE_DAYS" -lt 1 ]; then
    echo "Error: <max_age_days> must be an integer greater than 0."
    exit 1
fi

printf "\n\n"
echo "Checking if $SCRIPT_NAME ran in the last $MAX_AGE_DAYS days"

if [ ! -d "$LOGS_DIR" ]; then
    $script_dir/send_telegram_alert.sh "$(hostname) Warning:\n\n Log directory $LOGS_DIR does not exist, cannot verify that $SCRIPT_NAME is running."
    exit 2
fi

RECENT_LOG=$(find "$LOGS_DIR" -maxdepth 1 -type f -name "$SCRIPT_NAME-*.log" ! -name "*.error.log" -mtime -"$MAX_AGE_DAYS" -print -quit)

if [ -z "$RECENT_LOG" ]; then
    $script_dir/send_telegram_alert.sh "$(hostname) Warning:\n\n $SCRIPT_NAME has not run in the last $MAX_AGE_DAYS days.\n\nCheck the crontab entry and the script path."
    exit 3
fi

echo "Last run found: $RECENT_LOG"
exit 0
