#!/bin/bash

script_dir="$(dirname "$(readlink -f "$0")")"
# Check if a log file name was provided as an argument
if [ $# -eq 0 ]; then
    echo "Usage: $0 <log_file>"
    exit 1
fi

# Get the log file name from the first argument
LOG_FILE="$1"

# Variable to store file name and contents
log_info=""

printf "\n\n"
echo "Reviewing logs for errors"
# Check if the file is not empty
if [ -s "$LOG_FILE" ]; then
    # Append the file name and its contents to log_info
    log_info+="$LOG_FILE\n\n"
    log_info+=$(cat "$LOG_FILE")
    log_info+='\n\n'
fi

# Generate telegram alert if file is not empty
if [ -n "$log_info" ]; then
    echo "Error log file not empty. Sending Telegram Alert"
    $script_dir/send_telegram_alert.sh "$log_info"
else
   echo "Error log empty"
fi

