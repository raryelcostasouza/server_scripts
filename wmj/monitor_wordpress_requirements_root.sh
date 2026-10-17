#!/bin/bash

# Started by root's crontab only in order to drop privileges: wp-config.php is mode 0600
# and owned by www-data, so no other user on this host can read the database credentials.
# check_wordpress_requirements.sh queries the database as www-data, never as root.
#
# The path is absolute because "~" expands to /root here.

script_dir="$(dirname "$(readlink -f "$0")")"
source "$script_dir/../lib/vars_logging.sh"

$script_dir/../lib/check_wordpress_requirements.sh \
    /home/pmpanya/domains/watmarpjan.org/public_html/wp \
    php \
    www-data

$script_dir/../lib/check_if_error_log_not_empty.sh $ERROR_LOG_FILE
