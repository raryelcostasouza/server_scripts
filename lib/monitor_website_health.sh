#!/bin/bash

# See check_website_health.sh for why vars_logging.sh is not sourced here.

script_dir="$(dirname "$(readlink -f "$0")")"

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <expected_text> <url1> [url2 ... urlN]"
    exit 1
fi

# Shared by every URL: pass "" to only check reachability and the status code
EXPECTED_TEXT="$1"
shift

CHECK_SCRIPT="$script_dir/check_website_health.sh"

for URL in "$@"; do
    "$CHECK_SCRIPT" "$URL" "$EXPECTED_TEXT"
done
