#!/bin/bash

# Retrieve the number of days from the argument
days=7

# Determine the directory of the current script
script_dir="$(dirname "$(readlink -f "$0")")"

# Source the vars_logging.sh script for logging functions
source "$script_dir/vars_logging.sh"

# Define the date range based on the number of days
END_DATE=$(date "+%Y-%m-%d")
START_DATE=$(date -d "$END_DATE -$days days" "+%Y-%m-%d")

# Path to the log file
LOG_FILE="/var/log/unattended-upgrades/unattended-upgrades.log"

# Extract log entries from the specified date range
filtered_entries=$(awk -v start="$START_DATE" -v end="$END_DATE" '
    $0 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}/ {
        log_date = substr($0, 1, 10)
        if (log_date >= start && log_date <= end) {
            print
        }
    }
' "$LOG_FILE" | grep -iE 'error|warning')

# Check if filtered entries are empty
if [ -z "$filtered_entries" ]; then
    MESSAGE="$(hostname) No errors or warnings found in $LOG_FILE \nfrom $START_DATE \nto $END_DATE."
else
    MESSAGE="$(hostname) Found below warnings/errors in unattended-upgrades logs \nfrom $START_DATE \nto $END_DATE:\n\n$filtered_entries"
fi

# Send alert with the message
$script_dir/send_telegram_alert.sh "$MESSAGE"

# Check if error log file is not empty
$script_dir/check_if_error_log_not_empty.sh "$ERROR_LOG_FILE"
