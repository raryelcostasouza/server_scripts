#!/bin/bash

script_dir="$(dirname "$(readlink -f "$0")")"
source "$script_dir/../lib/vars_logging.sh"
source "$script_dir/../creds/duplicity.sh"

$script_dir/../lib/update_cron.sh "0 2 * * * /bin/bash -c "$script_dir/"backup_wp_files_and_DB.sh"
$script_dir/../lib/update_cron.sh "0 0 * * 1 /bin/bash -c "$script_dir/"monitor_disk_usage_wmj.sh"
$script_dir/../lib/update_cron.sh "0 6 * * 1 /bin/bash -c "$script_dir/"monitor_backups_wmj.sh"
$script_dir/../lib/update_cron.sh "0 7 * * 1 /bin/bash -c "$script_dir/"monitor_wordpress_requirements_wmj.sh"
# Redirected like ssh-login-monitor.sh: no vars_logging.sh, so the routine "is active"
# lines would otherwise mail the user every 15 minutes
$script_dir/../lib/update_cron.sh "*/15 * * * * /bin/bash -c "$script_dir/"monitor_service_status_wmj.sh >/dev/null"
$script_dir/../lib/update_cron.sh "30 3 1 * * /bin/bash -c "$script_dir/../lib/"clean_script_logs_older_n_days.sh"


$script_dir/../lib/check_if_error_log_not_empty.sh $ERROR_LOG_FILE