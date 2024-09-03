#!/bin/bash

script_dir="$(dirname "$(readlink -f "$0")")"
source "$script_dir/../lib/vars_logging.sh"
source "$script_dir/../creds/duplicity.sh"

$script_dir/../lib/update_cron.sh "0 0 * * * "$script_dir/"monitor_disk_usage_flux.sh"
$script_dir/../lib/update_cron.sh "0 * * * * "$script_dir/"monitor_node_confirmed_status.sh"
$script_dir/../lib/update_cron.sh "0 0 * * * "$script_dir/../lib/"monitor_logs_unattended_upgrades.sh"
$script_dir/../lib/update_cron.sh "30 3 1 * * "$script_dir/../lib/"clean_script_logs_older_n_days.sh"


$script_dir/../lib/check_if_error_log_not_empty.sh $ERROR_LOG_FILE