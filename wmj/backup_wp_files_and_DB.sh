#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Error: WordPress backups must run as root from a root-owned clone." >&2
    exit 1
fi
umask 077

script_dir="$(dirname "$(readlink -f "$0")")"
source "$script_dir/../creds/duplicity.sh"
source "$script_dir/../lib/vars_logging.sh"

# Report failures even when a prerequisite, dump or archive aborts the backup.
trap 'status=$?
    "$script_dir/../lib/check_if_error_log_not_empty.sh" "$ERROR_LOG_FILE"
    "$script_dir/../lib/check_log_for_errors.sh" "$STANDARD_LOG_FILE"
    exit "$status"' EXIT

# The site and its exclusion list stay in the hosting user's home; only working files use root's HOME.
WORDPRESS_BACKUP_SOURCE="${WORDPRESS_BACKUP_SOURCE:-/home/pmpanya/domains/watmarpjan.org}"
DUPLICITY_IGNORE_FILE="${DUPLICITY_IGNORE_FILE:-/home/pmpanya/.duplicity/ignore}"
if [[ "$WORDPRESS_BACKUP_SOURCE" != /* ]]; then
    echo "Error: WORDPRESS_BACKUP_SOURCE must be an absolute path, got '$WORDPRESS_BACKUP_SOURCE'." >&2
    exit 1
fi
if [ ! -d "$WORDPRESS_BACKUP_SOURCE" ]; then
    echo "Error: WordPress source directory '$WORDPRESS_BACKUP_SOURCE' does not exist." >&2
    exit 1
fi
if [[ "$DUPLICITY_IGNORE_FILE" != /* ]]; then
    echo "Error: DUPLICITY_IGNORE_FILE must be an absolute path, got '$DUPLICITY_IGNORE_FILE'." >&2
    exit 1
fi
if [ ! -r "$DUPLICITY_IGNORE_FILE" ]; then
    echo "Error: exclusion list '$DUPLICITY_IGNORE_FILE' is missing or unreadable." >&2
    exit 1
fi
mkdir -p "$HOME/DB" || exit 1

# Abort instead of running a backup that would silently produce nothing
$script_dir/../lib/check_required_commands.sh "$DUPLICITY_CMD" rclone mysqldump 7za || exit 1

#printf "\n\n"
#echo "Cleaning up incomplete orphan backups for WMJ.NET"
#$DUPLICITY_CMD cleanup --force rclone://gdrive://WMJ_Server_Backup/WMJ.NET

#printf "\n\n"
#echo "Cleaning up incomplete orphan backups for WMJ.COM"
#$DUPLICITY_CMD cleanup --force rclone://gdrive://WMJ_Server_Backup/WMJ.COM

printf "\n\n"
echo "Cleaning up incomplete orphan backups for WMJ.ORG"
$DUPLICITY_CMD --allow-source-mismatch cleanup --force rclone://gdrive://WMJ_Server_Backup/WMJ.ORG/duplicity

#printf "\n\n"
#echo "Removing backups older than 3 years for WMJ.NET"
#$DUPLICITY_CMD remove-older-than 3Y --force rclone://gdrive://WMJ_Server_Backup/WMJ.NET

#printf "\n\n"
#echo "Removing backups older than 3 years for WMJ.COM"
#$DUPLICITY_CMD remove-older-than 3Y --force rclone://gdrive://WMJ_Server_Backup/WMJ.COM

printf "\n\n"
echo "Removing backups older than 3 years for WMJ.ORG"
$DUPLICITY_CMD --allow-source-mismatch remove-older-than 3Y --force rclone://gdrive://WMJ_Server_Backup/WMJ.ORG/duplicity

#printf "\n\n"
#echo "Removing all incrementals older than 1 full backups for WMJ.NET"
#$DUPLICITY_CMD remove-all-inc-of-but-n-full 1 --force rclone://gdrive://WMJ_Server_Backup/WMJ.NET

#printf "\n\n"
#echo "Removing all incrementals older than 1 full backups for WMJ.COM"
#$DUPLICITY_CMD remove-all-inc-of-but-n-full 1 --force rclone://gdrive://WMJ_Server_Backup/WMJ.COM

printf "\n\n"
echo "Removing all incrementals older than 1 full backups for WMJ.ORG"
$DUPLICITY_CMD --allow-source-mismatch remove-all-inc-of-but-n-full 1 --force rclone://gdrive://WMJ_Server_Backup/WMJ.ORG/duplicity

#printf "\n\n"
#echo "Backing up WMJ.NET"
#backup wmj.net
#$DUPLICITY_CMD --full-if-older-than 1M --no-encryption ~/domains/watmarpjan.net rclone://gdrive://WMJ_Server_Backup/WMJ.NET

printf "\n\n"
echo "Backing up WMJ.ORG"
#backup wmj.org
$DUPLICITY_CMD --allow-source-mismatch --full-if-older-than 1M --exclude-filelist "$DUPLICITY_IGNORE_FILE" --no-encryption "$WORDPRESS_BACKUP_SOURCE" rclone://gdrive://WMJ_Server_Backup/WMJ.ORG/duplicity

#printf "\n\n"
#echo "Backing up WMJ.COM"
#backup wmj.com
#$DUPLICITY_CMD --full-if-older-than 1M ~/domains/watmarpjan.com rclone://gdrive://WMJ_Server_Backup/WMJ.COM

printf "\n\n"
echo "Cleaning up local DB backups older than 3 years"
find "$HOME/DB/" -maxdepth 1 -type f -name "*.7z" -mtime +1095 -exec rm {} +

printf "\n\n"
echo "Backing up DB"
#backup DB
mysqldump --databases wmj_guests wmj_org_wordpress > "$HOME/DB/backup.sql" || exit 1
7za "-p$PASSPHRASE_ZIP" a "$HOME/DB/backup-db-$TIMESTAMP.sql.7z" "$HOME/DB/backup.sql" || exit 1
rm -f "$HOME/DB/backup.sql"
rclone copy "$HOME/DB/" gdrive:WMJ_Server_Backup/DB/
