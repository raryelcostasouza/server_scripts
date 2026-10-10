#!/bin/bash

script_dir="$(dirname "$(readlink -f "$0")")"
source "$script_dir/../lib/vars_logging.sh"

$script_dir/../lib/check_wordpress_requirements.sh ~/domains/watmarpjan.org/public_html/wp

$script_dir/../lib/check_if_error_log_not_empty.sh $ERROR_LOG_FILE
