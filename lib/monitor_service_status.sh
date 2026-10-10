#!/bin/bash

# See check_service_status.sh for why vars_logging.sh is not sourced here.

script_dir="$(dirname "$(readlink -f "$0")")"

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <service1> [service2 ... serviceN]"
    exit 1
fi

CHECK_SCRIPT="$script_dir/check_service_status.sh"

for SERVICE in "$@"; do
    "$CHECK_SCRIPT" "$SERVICE"
done
