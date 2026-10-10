#!/bin/bash

script_dir="$(dirname "$(readlink -f "$0")")"

printf "\n\n"
echo "Validating the script paths referenced in the crontab"

INVALID_PATHS=""

while read -r CRON_SCRIPT_PATH; do
    if [ ! -x "$CRON_SCRIPT_PATH" ]; then
        INVALID_PATHS+="$CRON_SCRIPT_PATH\n"
    fi
done < <(crontab -l 2>/dev/null | grep -v '^[[:space:]]*#' | grep -o '/[^ "]*\.sh' | sort -u)

if [ -n "$INVALID_PATHS" ]; then
    $script_dir/send_telegram_alert.sh "$(hostname) Warning:\n\n The crontab references scripts that are missing or not executable:\n\n$INVALID_PATHS"
    exit 3
fi

echo "All crontab script paths are valid"
exit 0
