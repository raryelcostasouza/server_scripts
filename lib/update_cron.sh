#!/bin/bash

REMOVE_ONLY=false
if [ "$#" -eq 2 ] && [ "$1" = "--remove" ]; then
  REMOVE_ONLY=true
  CRON_SCRIPT_PATH="$2"
  NEW_CRON_ENTRY=""
elif [ "$#" -eq 1 ]; then
  NEW_CRON_ENTRY="$1"
  CRON_SCRIPT_PATH=$(echo "$NEW_CRON_ENTRY" | grep -o '/[^ "]*\.sh' | tail -n 1)
else
  echo "Usage: $0 \"<new-cron-entry>\" | --remove <absolute-script-path>"
  exit 1
fi

# Refuse to install an entry pointing at a script that cannot run, otherwise cron
# fails silently and the job never executes
if [ -z "$CRON_SCRIPT_PATH" ]; then
  echo "Error: no script path found in cron entry: $NEW_CRON_ENTRY"
  exit 1
fi

if [[ "$CRON_SCRIPT_PATH" != /*.sh ]]; then
  echo "Error: expected an absolute .sh script path."
  exit 1
fi

if [ "$REMOVE_ONLY" = false ] && [ ! -f "$CRON_SCRIPT_PATH" ]; then
  echo "Error: $CRON_SCRIPT_PATH is not a valid file."
  exit 1
fi

if [ "$REMOVE_ONLY" = false ] && [ ! -x "$CRON_SCRIPT_PATH" ]; then
  echo "Error: $CRON_SCRIPT_PATH is not executable."
  exit 1
fi

# Function to update crontab
update_crontab() {
  # Create a temporary file
  TEMP_CRON_FILE=$(mktemp)

  # List current crontab entries. A failed "crontab -l" must not be mistaken for an
  # empty crontab, otherwise the install below would wipe every unrelated entry.
  CRON_LIST_ERROR=$(crontab -l 2>&1 >"$TEMP_CRON_FILE")
  if [ $? -ne 0 ] && ! echo "$CRON_LIST_ERROR" | grep -qi "no crontab"; then
    echo "Error: could not read the current crontab, aborting without changes: $CRON_LIST_ERROR"
    rm -f "$TEMP_CRON_FILE"
    exit 1
  fi

  # Remove any previous entry for the same script, including entries with a
  # different schedule or an outdated script name. -F keeps paths and schedules
  # from being interpreted as regexes.
  if [ "$REMOVE_ONLY" = true ]; then
    grep -v -F -e "$CRON_SCRIPT_PATH" "$TEMP_CRON_FILE" > "$TEMP_CRON_FILE.new"
  else
    grep -v -F -e "$NEW_CRON_ENTRY" -e "$CRON_SCRIPT_PATH" "$TEMP_CRON_FILE" > "$TEMP_CRON_FILE.new"
    echo "$NEW_CRON_ENTRY" >> "$TEMP_CRON_FILE.new"
  fi

  # Install the new crontab file
  if ! crontab "$TEMP_CRON_FILE.new"; then
    echo "Error: failed to install the updated crontab for $CRON_SCRIPT_PATH."
    rm -f "$TEMP_CRON_FILE" "$TEMP_CRON_FILE.new"
    exit 1
  fi

  # Clean up
  rm -f "$TEMP_CRON_FILE" "$TEMP_CRON_FILE.new"
}

# Execute the function
update_crontab
