#!/bin/bash

# Check if a new cron entry was provided as an argument
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 \"<new-cron-entry>\""
  exit 1
fi

# New cron entry passed as an argument
NEW_CRON_ENTRY="$1"

# Function to update crontab
update_crontab() {
  # Create a temporary file
  TEMP_CRON_FILE=$(mktemp)

  # List current crontab entries
  crontab -l > "$TEMP_CRON_FILE" 2>/dev/null

  # Remove old entries for the same command
  grep -v "$NEW_CRON_ENTRY" "$TEMP_CRON_FILE" > "$TEMP_CRON_FILE.new"

  # Add the new entry
  echo "$NEW_CRON_ENTRY" >> "$TEMP_CRON_FILE.new"

  # Install the new crontab file
  crontab "$TEMP_CRON_FILE.new"

  # Clean up
  rm "$TEMP_CRON_FILE" "$TEMP_CRON_FILE.new"
}

# Execute the function
update_crontab
