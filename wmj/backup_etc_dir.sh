#!/bin/bash

script_dir="$(dirname "$(readlink -f "$0")")"

source "$script_dir/../lib/vars_logging.sh"
source "$script_dir/../creds/duplicity.sh"

printf "\n\n"
echo "Removing all incrementals older than 1 full backups"
$DUPLICITY_CMD --allow-source-mismatch remove-all-inc-of-but-n-full 1 --force rclone://gdrive://WMJ_Server_Backup/Server_Config/etc

printf "\n\n"
echo "Removing backups older than 3 years"
$DUPLICITY_CMD --allow-source-mismatch remove-older-than 3Y --force rclone://gdrive://WMJ_Server_Backup/Server_Config/etc

printf "\n\n"
echo "Backing up /etc folder"
$DUPLICITY_CMD --allow-source-mismatch --full-if-older-than 1M /etc rclone://gdrive://WMJ_Server_Backup/Server_Config/etc

$script_dir/../lib/check_if_error_log_not_empty.sh $ERROR_LOG_FILE
