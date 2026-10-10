#!/bin/bash

script_dir="$(dirname "$(readlink -f "$0")")"
source "$script_dir/../lib/vars_logging.sh"
source "$script_dir/../creds/duplicity.sh"

$script_dir/../lib/update_cron.sh "20 8 * * * /bin/bash -c "$script_dir/"backup_etc_dir.sh"
$script_dir/../lib/update_cron.sh "0 0 * * 1 /bin/bash -c "$script_dir/"certbot_health_check.sh"
$script_dir/../lib/update_cron.sh "0 0 * * 1 /bin/bash -c "$script_dir/../lib/"monitor_logs_unattended_upgrades.sh"
$script_dir/../lib/update_cron.sh "0 0 * * 1 /bin/bash -c "$script_dir/../generic/"fail2ban-monitor.sh"
$script_dir/../lib/update_cron.sh "30 3 1 * * /bin/bash -c "$script_dir/../lib/"clean_script_logs_older_n_days.sh"

# The maldet scan itself is scheduled manually as "0 19 * * 0 /usr/local/maldetect/maldet -a ...";
# update_cron.sh cannot manage it because the entry runs a binary rather than a .sh.
# This reads the resulting log two hours after the scan window.
$script_dir/../lib/update_cron.sh "0 21 * * 0 /bin/bash -c "$script_dir/"malware-detector-log-checker.sh"


$script_dir/../lib/check_if_error_log_not_empty.sh $ERROR_LOG_FILE