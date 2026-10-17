#!/bin/bash

script_dir="$(dirname "$(readlink -f "$0")")"
if [ "$EUID" -ne 0 ]; then
    echo "Error: run this installer as root from a root-owned clone." >&2
    exit 1
fi
source "$script_dir/../lib/vars_logging.sh"
source "$script_dir/../creds/duplicity.sh"

$script_dir/../lib/update_cron.sh "0 2 * * * /bin/bash -c "$script_dir/"backup_wp_files_and_DB.sh"
# The recent-run check looks in root's HOME alongside the backup logs.
$script_dir/../lib/update_cron.sh "0 18 * * 6 /bin/bash -c "$script_dir/"monitor_backups_wmj.sh"
$script_dir/../lib/update_cron.sh "20 8 * * * /bin/bash -c "$script_dir/"backup_etc_dir.sh"
# Daily: a weekly check can miss a failing renewal for six days, and certbot only starts
# renewing with 30 days left
$script_dir/../lib/update_cron.sh "0 5 * * * /bin/bash -c "$script_dir/"certbot_health_check.sh"
$script_dir/../lib/update_cron.sh "0 18 * * 6 /bin/bash -c "$script_dir/../lib/"monitor_logs_unattended_upgrades.sh"
# Scheduled here, not in the site user's crontab: only root can drop wp-cli to www-data,
# which is the only user able to read wp-config.php
$script_dir/../lib/update_cron.sh "0 18 * * 6 /bin/bash -c "$script_dir/"monitor_wordpress_integrity_root.sh"
# Same reason: only root can drop the database query to www-data, the only user able to
# read the credentials in wp-config.php
$script_dir/../lib/update_cron.sh "0 18 * * 6 /bin/bash -c "$script_dir/"monitor_wordpress_requirements_root.sh"
# Monthly: a restore test downloads and decrypts real backup data, too expensive to run weekly
$script_dir/../lib/update_cron.sh "0 6 1 * * /bin/bash -c "$script_dir/"monitor_backup_restore_root.sh"
$script_dir/../lib/update_cron.sh "0 18 * * 6 /bin/bash -c "$script_dir/../generic/"fail2ban-monitor.sh"
$script_dir/../lib/update_cron.sh "*/5 * * * * /bin/bash -c "$script_dir/../generic/"ssh-login-monitor.sh >/dev/null"
$script_dir/../lib/update_cron.sh "30 3 1 * * /bin/bash -c "$script_dir/../lib/"clean_script_logs_older_n_days.sh"

# The maldet scan itself is scheduled manually as "0 16 * * 6 /usr/local/maldetect/maldet -a ...";
# update_cron.sh cannot manage it because the entry runs a binary rather than a .sh.
# This reads the resulting log two hours after the scan window, with the other weekly alerts.
$script_dir/../lib/update_cron.sh "0 18 * * 6 /bin/bash -c "$script_dir/"malware-detector-log-checker.sh"


$script_dir/../lib/check_if_error_log_not_empty.sh $ERROR_LOG_FILE