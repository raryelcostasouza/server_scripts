#!/bin/bash

script_dir="$(dirname "$(readlink -f "$0")")"
source "$script_dir/../lib/vars_logging.sh"
source "$script_dir/../creds/duplicity.sh"

DATE=$(date +"%Y-%m-%d")
FILE_TAR=/tmp/backup-wmj-org_public_html-$DATE.tar.xz
FILE_7Z="/home/pmpanya/WMJ_Server_Backup/WMJ.ORG/public_html/backup-wmj-org_public_html-$DATE.7z"

tar --exclude='/home/pmpanya/domains/watmarpjan.org/public_html/wp/wp-content/uploads' \
--exclude='/home/pmpanya/domains/watmarpjan.org/public_html/wp/wp-content/updraft' \
--exclude='/home/pmpanya/domains/watmarpjan.org/public_html/wp/wp-content/backup' \
--exclude='/home/pmpanya/domains/watmarpjan.org/public_html/wp/wp-content/cache' \
 -cJvf $FILE_TAR ~/domains/watmarpjan.org/public_html  

7za -p$PASSPHRASE_ZIP a $FILE_7Z $FILE_TAR
rm -f $FILE_TAR

rclone sync ~/WMJ_Server_Backup/WMJ.ORG/public_html gdrive:WMJ_Server_Backup/WMJ.ORG/public_html

