#!/bin/bash

script_dir="$(dirname "$(readlink -f "$0")")"
source "$script_dir/../lib/vars_logging.sh"

# Check if the number of days argument is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <number_of_days>"
    exit 1
fi

# Retrieve the number of days from the argument
days="$1"

# Validate if the argument is a positive integer
if ! [[ "$days" =~ ^[0-9]+$ ]] || [ "$days" -le 0 ]; then
    echo "Error: <number_of_days> must be a positive integer."
    exit 1
fi

# Determine the directory of the current script
script_dir="$(dirname "$(readlink -f "$0")")"

# Print status message
printf "\n\n"
echo "Cleaning up logs older than $days days"

# Find and delete log files older than the specified number of days
find "$script_dir/../log/" -maxdepth 1 -type f -name "*.log" -mtime +"$days" -exec rm {} +

