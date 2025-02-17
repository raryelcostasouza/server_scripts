#!/bin/bash

# Determine the directory of the current script
script_dir="$(dirname "$(readlink -f "$0")")"

# Source the vars_logging.sh script for logging functions
source "$script_dir/../lib/vars_logging.sh"

# One-liner to monitor Fail2Ban logs for failed attempts and store them
failed_attempts=$(grep "Ban" /var/log/fail2ban.log | while read -r line; do echo "$line"; done)

# If there are any failed attempts, send an alert
if [[ -n "$failed_attempts" ]]; then
    MESSAGE="Failed login attempts detected:\n$failed_attempts"
    $script_dir/../lib/send_telegram_alert.sh "$MESSAGE"
fi

# Check if the error log file is not empty (if applicable)
$script_dir/../lib/check_if_error_log_not_empty.sh "$ERROR_LOG_FILE"