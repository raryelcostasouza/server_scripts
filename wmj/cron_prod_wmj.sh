#!/bin/bash

script_dir="$(dirname "$(readlink -f "$0")")"
source "$script_dir/../lib/vars_logging.sh"
source "$script_dir/../creds/duplicity.sh"

# These jobs now run from root's own clone and crontab.
"$script_dir/../lib/update_cron.sh" --remove "$script_dir/backup_wp_files_and_DB.sh" || exit 1
"$script_dir/../lib/update_cron.sh" --remove "$script_dir/monitor_backups_wmj.sh" || exit 1
# Hourly: a runaway log or a stuck duplicity cache fills a partition in hours, and
# check_partition_disk_usage.sh only alerts on a threshold crossing so this stays quiet
$script_dir/../lib/update_cron.sh "0 * * * * /bin/bash -c "$script_dir/"monitor_disk_usage_wmj.sh >/dev/null"
# Monthly: a restore test downloads and decrypts real backup data, too expensive to run weekly
$script_dir/../lib/update_cron.sh "0 4 1 * * /bin/bash -c "$script_dir/"monitor_backup_restore_wmj.sh"
$script_dir/../lib/update_cron.sh "0 7 1 * * /bin/bash -c "$script_dir/"monitor_domain_expiry_wmj.sh"
# Redirected like ssh-login-monitor.sh: no vars_logging.sh, so the routine "is active"
# lines would otherwise mail the user every 15 minutes
$script_dir/../lib/update_cron.sh "*/15 * * * * /bin/bash -c "$script_dir/"monitor_service_status_wmj.sh >/dev/null"
$script_dir/../lib/update_cron.sh "*/15 * * * * /bin/bash -c "$script_dir/"monitor_website_health_wmj.sh >/dev/null"
$script_dir/../lib/update_cron.sh "30 3 1 * * /bin/bash -c "$script_dir/../lib/"clean_script_logs_older_n_days.sh"


$script_dir/../lib/check_if_error_log_not_empty.sh $ERROR_LOG_FILE