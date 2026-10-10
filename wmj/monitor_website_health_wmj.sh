#!/bin/bash

# See check_website_health.sh for why vars_logging.sh is not sourced here.

script_dir="$(dirname "$(readlink -f "$0")")"

# The site is multi-language and each prefix is a separate WordPress entry point, so a
# crash can hit one language while the others still render.
# "wp-content" only appears once WordPress has rendered the page with its assets, so a
# blank or half-built 200 is caught too.
"$script_dir/../lib/monitor_website_health.sh" "wp-content" \
    "https://watmarpjan.org/" \
    "https://watmarpjan.org/en/" \
    "https://watmarpjan.org/pt/" \
    "https://watmarpjan.org/cn/"
