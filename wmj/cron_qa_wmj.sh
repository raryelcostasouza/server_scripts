#!/bin/bash

script_dir="$(dirname "$(readlink -f "$0")")"
source "$script_dir/../lib/vars_logging.sh"

echo "up
$script_dir/../lib/cron_qa_schedule.sh $script_dir/"backup_etc_dir.sh"
$script_dir/../lib/cron_qa_schedule.sh $script_dir/"backup_wp_files_and_DB.sh"
$script_dir/../lib/cron_qa_schedule.sh $script_dir/"monitor_disk_usage_wmj.sh"
$script_dir/../lib/cron_qa_schedule.sh $script_dir/../lib/"monitor_logs_unattended_upgrades.sh"
$scri