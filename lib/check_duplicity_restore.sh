#!/bin/bash

# Proves a duplicity backup is actually restorable by restoring one known file from the
# remote and inspecting it.
#
# check_remote_backup_freshness.sh only proves a recent backup exists. An archive can be
# recent and still be unrestorable (broken incremental chain, truncated upload, wrong
# passphrase) and the only moment that surfaces is the one where the backup is needed.
# "duplicity verify" is not used because it compares against the live site and a busy
# WordPress install always has changed files, which would make every run look like a problem.
#
# PASSPHRASE and DUPLICITY_CMD come from creds/duplicity.sh, sourced by the caller.

script_dir="$(dirname "$(readlink -f "$0")")"

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <duplicity_remote_url> <file_to_restore> <expected_text>"
    exit 1
fi

REMOTE_PATH="$1"
FILE_TO_RESTORE="$2"
EXPECTED_TEXT="$3"

DUPLICITY="${DUPLICITY_CMD:-duplicity}"

# A hung rclone transfer would otherwise keep the cron job alive indefinitely
RESTORE_TIMEOUT=900

alert() {
    "$script_dir/send_telegram_alert.sh" "$(hostname) Warning:\n\n$1"
}

printf "\n\n"
echo "Restoring $FILE_TO_RESTORE from $REMOTE_PATH to verify the backup"

TEMP_DIR=$(mktemp -d) || {
    alert "Could not create a temporary directory, the backup restore test for $REMOTE_PATH did not run."
    exit 2
}
trap 'rm -rf "$TEMP_DIR"' EXIT

RESTORE_TARGET="$TEMP_DIR/restored"

RESTORE_OUTPUT=$(timeout "$RESTORE_TIMEOUT" "$DUPLICITY" restore --allow-source-mismatch --force \
    --file-to-restore "$FILE_TO_RESTORE" "$REMOTE_PATH" "$RESTORE_TARGET" 2>&1)
RESTORE_STATUS=$?

if [ "$RESTORE_STATUS" -ne 0 ]; then
    # Truncated because Telegram rejects messages over 4096 characters
    alert "The backup at $REMOTE_PATH is not restorable: restoring $FILE_TO_RESTORE failed (exit $RESTORE_STATUS).\n\n$(printf '%s\n' "$RESTORE_OUTPUT" | tail -n 15)"
    exit 3
fi

if [ ! -s "$RESTORE_TARGET" ]; then
    alert "The backup at $REMOTE_PATH restored $FILE_TO_RESTORE as an empty file, so its contents are not being backed up correctly."
    exit 3
fi

# Catches an archive that restores a file of the right size but the wrong content, which
# is what a failed decryption or a corrupted volume looks like
if ! grep -qF "$EXPECTED_TEXT" "$RESTORE_TARGET"; then
    alert "The backup at $REMOTE_PATH restored $FILE_TO_RESTORE, but it does not contain the expected content. The archive is damaged or the passphrase is wrong."
    exit 3
fi

echo "$FILE_TO_RESTORE restored successfully and contains the expected content."
exit 0
