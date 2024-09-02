#!/bin/bash

script_dir="$(dirname "$(readlink -f "$0")")"
source "$script_dir/../lib/vars_logging.sh"

# Retrieve the number of days from the argument
days=90

# Determine the directory of the current script
script_dir="$(dirname "$(readlink -f "$0")")"

# Print status message
printf "\n\n"
echo "Cleaning up logs older than $days days"

# Find and delete log files older than the specified number of days
find "~/server_scripts_logs/" -maxdepth 1 -type f -name "*.log" -mtime +"$days" -exec rm {} +

