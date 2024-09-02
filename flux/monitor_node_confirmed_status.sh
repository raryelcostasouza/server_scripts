#!/bin/bash

# Check if exactly one argument (node identifier) is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <node_identifier>"
    exit 1
fi

# Retrieve the node identifier from the argument
node_identifier="$1"

# Validate that the node identifier is a non-empty string
if [ -z "$node_identifier" ]; then
    echo "Error: <node_identifier> must be a non-empty string."
    exit 1
fi

# Determine the directory of the current script
script_dir="$(dirname "$(readlink -f "$0")")"

# Source the vars_logging.sh script for logging functions
source "$script_dir/../lib/vars_logging.sh"

# Run the command to get the node status
result=$(/usr/local/bin/flux-cli getzelnodestatus)

# Extract the status and IP fields from the JSON output
status=$(echo "$result" | jq -r '.status')
ip=$(echo "$result" | jq -r '.ip')

# Check the status and handle accordingly
if [ "$status" == "CONFIRMED" ]; then
    echo "Node $node_identifier: $ip | status:Confirmed"
else
    MESSAGE="Node $node_identifier: $ip | status:$status"
    $script_dir/../lib/send_telegram_alert.sh "$MESSAGE"
fi

# Check if the error log file is not empty
$script_dir/../lib/check_if_error_log_not_empty.sh "$ERROR_LOG_FILE"
