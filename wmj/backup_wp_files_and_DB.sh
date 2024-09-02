#!/bin/bash

script_dir="$(dirname "$(readlink -f "$0")")"
source $script_dir/../creds/duplicity.sh
source $script_dir/../lib/vars_logging.sh

#printf "\n\n"
#echo "Cleaning up incomplete orphan backups for WMJ.NET"
#$DUPLICITY_CMD cleanup --force rclone://gdrive://WMJ_Server_Backup/WMJ.NET

#printf "\n\n"
#echo "Cleaning up incomplete orphan backups for WMJ.COM"
#$DUPLICITY_CMD cleanup --force rclone://gdrive://WMJ_Server_Backup/WMJ.COM

printf "\n\n"
echo "Cleaning up incomplete orphan backups for WMJ.ORG"
$DUPLICITY_CMD cleanup --force rclone://gdrive://WMJ_Server_Backup/WMJ.ORG/duplicity

#printf "\n\n"
#echo "Removing backups older than 3 years for WMJ.NET"
#$DUPLICITY_CMD remove-older-than 3Y --force rclone://gdrive://WMJ_Server_Backup/WMJ.NET

#printf "\n\n"
#echo "Removing backups older than 3 years for WMJ.COM"
#$DUPLICITY_CMD remove-older-than 3Y --force rclone://gdrive://WMJ_Server_Backup/WMJ.COM

printf "\n\n"
echo "Removing backups older than 3 years for WMJ.ORG"
$DUPLICITY_CMD remove-older-than 3Y --force rclone://gdrive://WMJ_Server_Backup/WMJ.ORG/duplicity

#printf "\n\n"
#echo "Removing all incrementals older than 1 full backups for WMJ.NET"
#$DUPLICITY_CMD remove-all-inc-of-but-n-full 1 --force rclone://gdrive://WMJ_Server_Backup/WMJ.NET

#printf "\n\n"
#echo "Removing all incrementals older than 1 full backups for WMJ.COM"
#$DUPLICITY_CMD remove-all-inc-of-but-n-full 1 --force rclone://gdrive://WMJ_Server_Backup/WMJ.COM

printf "\n\n"
echo "Removing all incrementals older than 1 full backups for WMJ.ORG"
$DUPLICITY_CMD remove-all-inc-of-but-n-full 1 --force rclone://gdrive://WMJ_Server_Backup/WMJ.ORG/duplicity

#printf "\n\n"
#echo "Backing up WMJ.NET"
#backup wmj.net
#$DUPLICITY_CMD --full-if-older-than 1M --no-encryption ~/domains/watmarpjan.net rclone://gdrive://WMJ_Server_Backup/WMJ.NET

printf "\n\n"
echo "Backing up WMJ.ORG"
#backup wmj.org
$DUPLICITY_CMD --full-if-older-than 1M --exclude-filelist ~/.duplicity/ignore --no-encryption ~/domains/watmarpjan.org rclone://gdrive://WMJ_Server_Backup/WMJ.ORG/duplicity

#printf "\n\n"
#echo "Backing up WMJ.COM"
#backup wmj.com
#$DUPLICITY_CMD --full-if-older-than 1M ~/domains/watmarpjan.com rclone://gdrive://WMJ_Server_Backup/WMJ.COM

printf "\n\n"
echo "Cleaning up local DB backups older than 3 years"
find ~/DB/ -maxdepth 1 -type f -name "*.7z" -mtime +1095 -exec rm {} +

printf "\n\n"
echo "Backing up DB"
#backup DB
mysqldump --databases wmj_guests wmj_org_wordpress > ~/DB/backup.sql
7za -p$PASSPHRASE_ZIP a ~/DB/backup-db-$TIMESTAMP.sql.7z ~/DB/backup.sql
rm -f ~/DB/backup.sql
rclone copy ~/DB/ gdrive:WMJ_Server_Backup/DB/

$script_dir/../lib/check_if_error_log_not_empty.sh $ERROR_LOG_FILE
