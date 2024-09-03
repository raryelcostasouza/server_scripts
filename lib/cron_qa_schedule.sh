#!/bin/bash

# Determine the directory of the current script
script_dir="$(dirname "$(readlink -f "$0")")"

# Check if a script file path was provided as an argument
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <script-file-path>"
  exit 1
fi

SCRIPT_PATH="$1"

# Validate the script path
if [ ! -f "$SCRIPT_PATH" ]; then
  echo "Error: $SCRIPT_PATH is not a valid file."
  exit 1
fi

if [ ! -x "$SCRIPT_PATH" ]; then
  echo "Error: $SCRIPT_PATH is not executable."
  exit 1
fi

# Path to the update_cron.sh script
UPDATE_CRON_SCRIPT="$script_dir/update_cron.sh"

# Check if the update_cron.sh script exists
if [ ! -x "$UPDATE_CRON_SCRIPT" ]; then
  echo "Error: $UPDATE_CRON_SCRIPT not found or not executable."
  exit 1
fi

# Create a cron entry for the provided script to run every 2 minutes
CRON_ENTRY="*/2 * * * * $SCRIPT_PATH"

# Call update_cron.sh to add or update the cron entry
"$UPDATE_CRON_SCRIPT" "$CRON_ENTRY"
