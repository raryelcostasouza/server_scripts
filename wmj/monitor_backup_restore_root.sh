#!/bin/bash

# Monthly proof that the /etc backup can actually be restored. Runs as root because the
# rclone remote and the duplicity archive for /etc belong to root.

script_dir="$(dirname "$(readlink -f "$0")")"
source "$script_dir/../lib/vars_logging.sh"
source "$script_dir/../creds/duplicity.sh"

$script_dir/../lib/check_required_commands.sh "$DUPLICITY_CMD" rclone || exit 1

# passwd is small, always present and always contains the root entry, so restoring it
# exercises the whole chain (remote, volumes, manifest, passphrase) at almost no cost
$script_dir/../lib/check_duplicity_restore.sh \
    rclone://gdrive://WMJ_Server_Backup/Server_Config/etc \
    passwd \
    'root:'

$script_dir/../lib/check_if_error_log_not_empty.sh $ERROR_LOG_FILE
