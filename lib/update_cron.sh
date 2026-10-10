#!/bin/bash

# Check if a new cron entry was provided as an argument
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 \"<new-cron-entry>\""
  exit 1
fi

# New cron entry passed as an argument
NEW_CRON_ENTRY="$1"

# Path of the script the cron entry is supposed to run
CRON_SCRIPT_PATH=$(echo "$NEW_CRON_ENTRY" | grep -o '/[^ "]*\.sh' | tail -n 1)

# Refuse to install an entry pointing at a script that cannot run, otherwise cron
# fails silently and the job never executes
if [ -z "$CRON_SCRIPT_PATH" ]; then
  echo "Error: no script path found in cron entry: $NEW_CRON_ENTRY"
  exit 1
fi

if [ ! -f "$CRON_SCRIPT_PATH" ]; then
  echo "Error: $CRON_SCRIPT_PATH is not a valid file."
  exit 1
fi

if [ ! -x "$CRON_SCRIPT_PATH" ]; then
  echo "Error: $CRON_SCRIPT_PATH is not executable."
  exit 1
fi

# Function to update crontab
update_crontab() {
  # Create a temporary file
  TEMP_CRON_FILE=$(mktemp)

  # List current crontab entries
  crontab -l > "$TEMP_CRON_FILE" 2>/dev/null

  # Remove any previous entry for the same script, including entries with a
  # different schedule or an outdated script name
  grep -v -e "$NEW_CRON_ENTRY" -e "$CRON_SCRIPT_PATH" "$TEMP_CRON_FILE" > "$TEMP_CRON_FILE.new"

  # Add the new entry
  echo "$NEW_CRON_ENTRY" >> "$TEMP_CRON_FILE.new"

  # Install the new crontab file
  crontab "$TEMP_CRON_FILE.new"

  # Clean up
  rm "$TEMP_CRON_FILE" "$TEMP_CRON_FILE.new"
}

# Execute the function
update_crontab
