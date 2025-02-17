#!/bin/bash

# Retrieve the node identifier from the argument
node_identifier=$(hostname)

# Determine the directory of the current script
script_dir="$(dirname "$(readlink -f "$0")")"

# Source the vars_logging.sh script for logging functions
source "$script_dir/../lib/vars_logging.sh"

# Get the external public IP of the node
external_ip=$(curl -s http://checkip.amazonaws.com)

# Send the external IP through Telegram
MESSAGE="Node $node_identifier: External IP: $external_ip"

$script_dir/../lib/send_telegram_alert.sh "$MESSAGE"

# Optionally, you can retrieve the Flux node status if necessary
result=$(/usr/local/bin/flux-cli getzelnodestatus)

# Extract the status and IP fields from the JSON output
status=$(echo "$result" | jq -r '.status')
flux_ip=$(echo "$result" | jq -r '.ip')

# Check the status and handle accordingly
if [ "$status" == "CONFIRMED" ]; then
    echo "Node $node_identifier: Flux IP $flux_ip | status:Confirmed"
else
    MESSAGE="Node $node_identifier: Flux IP $flux_ip | status:$status"
    $script_dir/../lib/send_telegram_alert.sh "$MESSAGE"
fi

# Check if the error log file is not empty (assuming the log file is set in ERROR_LOG_FILE)
$script_dir/../lib/check_if_error_log_not_empty.sh "$ERROR_LOG_FILE"