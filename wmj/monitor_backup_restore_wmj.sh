#!/bin/bash

# Monthly proof that the backups can actually be restored.
#
# monitor_backups_wmj.sh checks that recent backups exist; this checks that they are
# usable. Both are needed: an untested backup is only a belief that the site can be
# recovered.

script_dir="$(dirname "$(readlink -f "$0")")"
source "$script_dir/../lib/vars_logging.sh"
source "$script_dir/../creds/duplicity.sh"

$script_dir/../lib/check_required_commands.sh "$DUPLICITY_CMD" rclone 7za || exit 1

# version.php is small, always present and its contents are unmistakable, so restoring it
# exercises the whole chain (remote, volumes, manifest) at almost no cost
$script_dir/../lib/check_duplicity_restore.sh \
    rclone://gdrive://WMJ_Server_Backup/WMJ.ORG/duplicity \
    public_html/wp/wp-includes/version.php \
    '$wp_version'

printf "\n\n"
echo "Verifying that the newest database dump can be decrypted and read"

DB_REMOTE="gdrive:WMJ_Server_Backup/DB"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Dump names carry a timestamp, so the newest modification time is the newest dump
NEWEST_DUMP=$(rclone lsf --files-only --include "*.7z" --format "tp" "$DB_REMOTE" | sort -r | head -n 1 | cut -d';' -f2)

if [ -z "$NEWEST_DUMP" ]; then
    $script_dir/../lib/send_telegram_alert.sh "$(hostname) Warning:\n\n No database dump was found at $DB_REMOTE, so the restore test could not run."
else
    echo "Testing $NEWEST_DUMP"

    if ! rclone copy "$DB_REMOTE/$NEWEST_DUMP" "$TEMP_DIR" 2>&1; then
        $script_dir/../lib/send_telegram_alert.sh "$(hostname) Warning:\n\n The database dump $NEWEST_DUMP could not be downloaded from $DB_REMOTE."
    # A wrong or lost passphrase makes every dump useless and only shows up here
    elif ! 7za x -p"$PASSPHRASE_ZIP" -o"$TEMP_DIR" -y "$TEMP_DIR/$NEWEST_DUMP" >/dev/null 2>&1; then
        $script_dir/../lib/send_telegram_alert.sh "$(hostname) Warning:\n\n The database dump $NEWEST_DUMP could not be extracted. The archive is corrupt or the 7zip passphrase no longer matches."
    else
        RESTORED_SQL=$(find "$TEMP_DIR" -maxdepth 1 -type f -name "*.sql" -print -quit)
        DUMP_PROBLEMS=""

        if [ -z "$RESTORED_SQL" ]; then
            DUMP_PROBLEMS+="The archive contains no .sql file.\n"
        else
            # mysqldump writes this line last, so its absence means the dump was cut short
            # while it was being written and would restore an incomplete database
            grep -q "Dump completed" "$RESTORED_SQL" || DUMP_PROBLEMS+="The dump has no \"Dump completed\" marker, so it was truncated.\n"

            for DATABASE in wmj_guests wmj_org_wordpress; do
                grep -q "USE \`$DATABASE\`" "$RESTORED_SQL" || DUMP_PROBLEMS+="The database $DATABASE is missing from the dump.\n"
            done

            grep -q "CREATE TABLE \`wp_options\`" "$RESTORED_SQL" || DUMP_PROBLEMS+="The WordPress wp_options table is missing from the dump.\n"
        fi

        if [ -n "$DUMP_PROBLEMS" ]; then
            $script_dir/../lib/send_telegram_alert.sh "$(hostname) Warning:\n\n The database backup $NEWEST_DUMP is not usable:\n\n$DUMP_PROBLEMS"
        else
            echo "$NEWEST_DUMP decrypts and contains both databases."
        fi
    fi
fi

$script_dir/../lib/check_if_error_log_not_empty.sh $ERROR_LOG_FILE
