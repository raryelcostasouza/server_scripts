#!/bin/bash

script_dir="$(dirname "$(readlink -f "$0")")"

# Check if at least one command was provided
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <command1> [command2 ... commandN]"
    exit 1
fi

printf "\n\n"
echo "Checking required commands: $*"

MISSING_COMMANDS=""

for REQUIRED_COMMAND in "$@"; do
    if [ -z "$REQUIRED_COMMAND" ]; then
        MISSING_COMMANDS+="(empty value, a command variable is unset)\n"
    elif ! command -v "$REQUIRED_COMMAND" >/dev/null 2>&1; then
        MISSING_COMMANDS+="$REQUIRED_COMMAND\n"
    fi
done

if [ -n "$MISSING_COMMANDS" ]; then
    $script_dir/send_telegram_alert.sh "$(hostname) Warning:\n\n Required commands are missing or not executable:\n\n$MISSING_COMMANDS\nThe scripts depending on them cannot run. Check the paths after any OS upgrade."
    exit 3
fi

echo "All required commands are available"
exit 0
