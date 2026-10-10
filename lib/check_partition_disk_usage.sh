#!/bin/bash

# Alerts when a partition crosses the usage threshold, and once more when it recovers.
# A healthy partition stays silent, so this can run hourly without becoming noise.
#
# Reports space usage (df) or inode usage (df -i): a partition can run out of inodes
# while df shows plenty of free space, and WordPress plus duplicity caches create exactly
# the kind of many-small-files workload that gets there.
#
# vars_logging.sh is deliberately not sourced: this runs at an hourly cron cadence and
# would otherwise leave dozens of log files a day in ~/server_scripts_logs.

script_dir="$(dirname "$(readlink -f "$0")")"

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    echo "Usage: $0 <partition> <threshold_percentage> [space|inodes]"
    exit 1
fi

PARTITION="$1"
THRESHOLD="$2"
METRIC="${3:-space}"

# A partition sitting just above the threshold would otherwise stay silent while it keeps
# filling, so a further climb of this many points alerts again
ESCALATION_POINTS=5

# Validate the threshold argument
if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]] || [ "$THRESHOLD" -lt 0 ] || [ "$THRESHOLD" -gt 100 ]; then
    echo "Error: Invalid threshold percentage. It must be a number between 0 and 100."
    exit 1
fi

case "$METRIC" in
    space) DF_FLAG="-P" ; LABEL="disk" ;;
    inodes) DF_FLAG="-Pi" ; LABEL="inode" ;;
    *) echo "Error: metric must be \"space\" or \"inodes\"." ; exit 1 ;;
esac

STATE_DIR="$HOME/server_scripts_logs"
"$script_dir/create_logs_dir.sh" >/dev/null

# Does not end in .log, so clean_script_logs_older_n_days.sh leaves it alone
OVER_MARKER="$STATE_DIR/disk-usage.$METRIC.$(printf '%s' "$PARTITION" | tr -c '[:alnum:]._-' '_').over"

alert() {
    "$script_dir/send_telegram_alert.sh" "$1"
}

# The argument can be either a device ($1) or a mount point ($6)
USAGE=$(df $DF_FLAG 2>/dev/null | awk -v p="$PARTITION" 'NR > 1 && ($1 == p || $6 == p) { print $5; exit }' | tr -d '%')

# Check if the partition was found and usage is correctly parsed
if [ -z "$USAGE" ]; then
    echo "Partition $PARTITION not found."
    exit 2
fi

# btrfs and zfs report "-" instead of an inode count, so there is nothing to compare
if ! [[ "$USAGE" =~ ^[0-9]+$ ]]; then
    echo "$PARTITION does not report $LABEL usage, skipping."
    exit 0
fi

if [ "$USAGE" -le "$THRESHOLD" ]; then
    # Only alerts when the partition was previously over the threshold, so a healthy run stays quiet
    if [ -f "$OVER_MARKER" ]; then
        alert "$(hostname) $PARTITION $LABEL usage is back to ${USAGE}%, below the ${THRESHOLD}% threshold."
        rm -f "$OVER_MARKER"
    fi
    echo "$PARTITION $LABEL usage is at ${USAGE}%. No action needed."
    exit 0
fi

# Throttled with a marker file holding the level already reported, otherwise a partition
# left above the threshold alerts on every run
LAST_ALERTED=$(cat "$OVER_MARKER" 2>/dev/null)
[[ "$LAST_ALERTED" =~ ^[0-9]+$ ]] || LAST_ALERTED=""

if [ -z "$LAST_ALERTED" ] || [ "$USAGE" -ge $((LAST_ALERTED + ESCALATION_POINTS)) ]; then
    alert "$(hostname) Warning:\n\n $PARTITION $LABEL usage is at ${USAGE}% (threshold ${THRESHOLD}%)."
    echo "$USAGE" > "$OVER_MARKER"
fi

echo "$PARTITION $LABEL usage is at ${USAGE}%."
exit 3
