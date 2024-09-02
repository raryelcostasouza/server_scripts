#!/bin/bash

script_dir="$(dirname "$(readlink -f "$0")")"
source $script_dir/../creds/telegram.sh

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <partition> <threshold_percentage>"
    exit 1
fi

# Get the partition and threshold arguments
PARTITION=$1
THRESHOLD=$2


# Validate the threshold argument
if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]] || [ "$THRESHOLD" -lt 0 ] || [ "$THRESHOLD" -gt 100 ]; then
    echo "Error: Invalid threshold percentage. It must be a number between 0 and 100."
    exit 1
fi


# Check disk usage using df -h and parse the output
USAGE=$(df -h | grep "$PARTITION" | awk '{print $5}' | sed 's/%//')

# Check if the partition was found and usage is correctly parsed
if [ -z "$USAGE" ]; then
    echo "Partition $PARTITION not found."
    exit 2
fi

# Check if usage is greater than Threshold
if [ "$USAGE" -gt $THRESHOLD ]; then
    $script_dir/send_telegram_alert.sh "Warning:\n\n $PARTITION usage is at ${USAGE}%." 
    exit 3
else
    $script_dir/send_telegram_alert.sh "$PARTITION usage is at ${USAGE}%. No action needed."
   exit 0
fi
