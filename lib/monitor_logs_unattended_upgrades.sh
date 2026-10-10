#!/bin/bash

# Retrieve the number of days from the argument
days=7

# Pending upgrades above this count are reported as a problem. unattended-upgrades
# only installs the allowed origins (security by default), so regular updates pile
# up while the log stays clean.
PENDING_THRESHOLD=20

# Package lists older than this many days make the pending counts unreliable
APT_LISTS_MAX_AGE_DAYS=2

# Determine the directory of the current script
script_dir="$(dirname "$(readlink -f "$0")")"

# Source the vars_logging.sh script for logging functions
source "$script_dir/vars_logging.sh"

$script_dir/check_required_commands.sh apt-get apt-config || exit 3

# Define the date range based on the number of days
END_DATE=$(date "+%Y-%m-%d")
START_DATE=$(date -d "$END_DATE -$days days" "+%Y-%m-%d")

# Path to the log file
LOG_FILE="/var/log/unattended-upgrades/unattended-upgrades.log"

# Problems worth acting on, collected across all the checks below
PROBLEMS=""

# Informational summary, always reported
SUMMARY=""

printf "\n\n"
echo "Reading unattended-upgrades logs from $START_DATE to $END_DATE"

# Rotated logs are included so the whole window is covered
log_files=()
for candidate in "$LOG_FILE" "$LOG_FILE".*; do
    [ -f "$candidate" ] && log_files+=("$candidate")
done

if [ ${#log_files[@]} -eq 0 ]; then
    PROBLEMS+="No unattended-upgrades log found at $LOG_FILE (is unattended-upgrades installed?).\n\n"
else
    entries_in_range=$(zcat -f "${log_files[@]}" | awk -v start="$START_DATE" -v end="$END_DATE" '
        $0 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}/ {
            log_date = substr($0, 1, 10)
            if (log_date >= start && log_date <= end) {
                print
            }
        }
    ')

    filtered_entries=$(echo "$entries_in_range" | grep -iE 'error|warning')
    if [ -n "$filtered_entries" ]; then
        PROBLEMS+="Warnings/errors in unattended-upgrades logs:\n$filtered_entries\n\n"
    fi

    run_count=$(echo "$entries_in_range" | grep -c 'Starting unattended upgrades script')
    if [ "$run_count" -eq 0 ]; then
        PROBLEMS+="unattended-upgrades did not run at all in the last $days days.\n\n"
    fi
    SUMMARY+="unattended-upgrades runs in the last $days days: $run_count\n"
fi

printf "\n\n"
echo "Checking that unattended-upgrades is enabled"

unattended_enabled=$(apt-config dump APT::Periodic::Unattended-Upgrade 2>/dev/null | awk -F'"' '{print $2}')
if [ "$unattended_enabled" != "1" ]; then
    PROBLEMS+="APT::Periodic::Unattended-Upgrade is \"${unattended_enabled:-unset}\", automatic upgrades are not active.\n\n"
fi

printf "\n\n"
echo "Checking the age of the apt package lists"

lists_stamp="/var/lib/apt/periodic/update-success-stamp"
[ -f "$lists_stamp" ] || lists_stamp="/var/lib/apt/lists"
if [ -e "$lists_stamp" ]; then
    lists_age_days=$(( ( $(date +%s) - $(stat -c %Y "$lists_stamp") ) / 86400 ))
    SUMMARY+="apt package lists refreshed $lists_age_days day(s) ago\n"
    if [ "$lists_age_days" -gt "$APT_LISTS_MAX_AGE_DAYS" ]; then
        PROBLEMS+="apt package lists are $lists_age_days days old, pending upgrade counts below are unreliable.\n\n"
    fi
fi

printf "\n\n"
echo "Counting pending upgrades"

# Simulation only, never installs anything. NoLocking lets this run as a non-root user.
apt_simulation=$(apt-get -s -q -o Debug::NoLocking=true upgrade 2>/dev/null)
pending_total=$(echo "$apt_simulation" | grep -c '^Inst ')
pending_security=$(echo "$apt_simulation" | grep '^Inst ' | grep -ciE '[-/]security')
pending_other=$(( pending_total - pending_security ))

# Packages apt upgrade refuses to touch (phased or new dependencies), invisible in the counts above
kept_back=$(echo "$apt_simulation" | awk '
    /^The following packages have been kept back:/ { flag = 1; next }
    flag && /^[[:space:]]/ { print; next }
    flag { flag = 0 }
' | tr -s ' \n' ' ')

SUMMARY+="Pending upgrades: $pending_total (security: $pending_security, other: $pending_other)\n"

if [ "$pending_security" -gt 0 ]; then
    PROBLEMS+="$pending_security security upgrade(s) still pending although unattended-upgrades should install them.\n\n"
fi

if [ "$pending_total" -ge "$PENDING_THRESHOLD" ]; then
    PROBLEMS+="$pending_total upgrades are pending (threshold $PENDING_THRESHOLD). Run apt update && apt upgrade.\n\n"
fi

if [ -n "$kept_back" ]; then
    PROBLEMS+="Packages kept back (need apt full-upgrade):\n$kept_back\n\n"
fi

if [ -f /var/run/reboot-required ]; then
    reboot_pkgs=$(tr '\n' ' ' < /var/run/reboot-required.pkgs 2>/dev/null)
    PROBLEMS+="Reboot required${reboot_pkgs:+ for: $reboot_pkgs}\n\n"
fi

if [ -z "$PROBLEMS" ]; then
    MESSAGE="$(hostname) Updates are healthy \nfrom $START_DATE \nto $END_DATE.\n\n$SUMMARY"
else
    MESSAGE="$(hostname) Update problems found \nfrom $START_DATE \nto $END_DATE:\n\n$PROBLEMS$SUMMARY"
fi

# Send alert with the message
$script_dir/send_telegram_alert.sh "$MESSAGE"

# Check if error log file is not empty
$script_dir/check_if_error_log_not_empty.sh "$ERROR_LOG_FILE"
