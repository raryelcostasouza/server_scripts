#!/bin/bash

script_dir="$(dirname "$(readlink -f "$0")")"
source "$script_dir/../lib/vars_logging.sh"

# Daily backups, so a 3 day window absorbs a single failed run before alerting
$script_dir/../lib/check_script_ran_recently.sh 3 backup_wp_files_and_DB.sh

$script_dir/../lib/check_remote_backup_freshness.sh 3 gdrive:WMJ_Server_Backup/DB
$script_dir/../lib/check_remote_backup_freshness.sh 3 gdrive:WMJ_Server_Backup/WMJ.ORG/duplicity
$script_dir/../lib/check_remote_backup_freshness.sh 3 gdrive:WMJ_Server_Backup/Server_Config/etc

$script_dir/../lib/check_cron_entries_valid.sh

$script_dir/../lib/check_if_error_log_not_empty.sh $ERROR_LOG_FILE
