#!/bin/bash

# Check if at least two arguments are provided (threshold and partitions)
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <threshold_percentage> partition1 [partition2 ... partitionN]"
    exit 1
fi

# Retrieve the threshold percentage from the first argument
threshold="$1"

# Validate if the threshold is a valid percentage (0-100)
if ! [[ "$threshold" =~ ^[0-9]+$ ]] || [ "$threshold" -lt 0 ] || [ "$threshold" -gt 100 ]; then
    echo "Error: <threshold_percentage> must be an integer between 0 and 100."
    exit 1
fi

# Retrieve the partitions from the remaining arguments
partitions=("${@:2}")

# Determine the directory of the current script
script_dir="$(dirname "$(readlink -f "$0")")"

# Source the vars_logging.sh script for logging functions
source "$script_dir/vars_logging.sh"

# Path to the check_disk_usage.sh script
CHECK_SCRIPT="$script_dir/check_partition_disk_usage.sh"

# Loop through each provided partition and check its usage
for PARTITION in "${partitions[@]}"; do
    echo "Checking usage for $PARTITION..."
    $CHECK_SCRIPT "$PARTITION" "$threshold"
done

# Check if the error log file is not empty
$script_dir/check_if_error_log_not_empty.sh "$ERROR_LOG_FILE"
