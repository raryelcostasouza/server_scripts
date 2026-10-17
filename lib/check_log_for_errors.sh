#!/bin/bash

script_dir="$(dirname "$(readlink -f "$0")")"

# Check if a log file name was provided as an argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <log_file>"
    exit 1
fi

LOG_FILE="$1"

printf "\n\n"
# Wording here deliberately avoids the keywords below, because this script writes
# to the same standard log it is about to scan
echo "Reviewing standard log for reported problems"

if [ ! -r "$LOG_FILE" ]; then
    $script_dir/send_telegram_alert.sh "$(hostname) Warning:\n\n$LOG_FILE is missing or not readable, the run could not be verified."
    exit 1
fi

# duplicity, rclone and 7za report most problems on stdout and still exit 0, so an
# empty stderr log is not enough to conclude the backup worked
PROBLEM_PATTERN='\berrors?\b|\bfailed\b|\bfailure[sd]?\b|\bfatal\b|traceback|permission denied|no such file|giving up|\bcannot\b|unable to|\bcorrupt'

# Summary counters that report a healthy run would otherwise match the pattern above
BENIGN_PATTERN='\berrors?\b[[:space:]:]+0\b|\bfailures?\b[[:space:]:]+0\b|^[0-9]+:Reviewing logs for errors$|^[0-9]+:Error log empty$'

MATCHES=$(grep -inE "$PROBLEM_PATTERN" "$LOG_FILE" | grep -ivE "$BENIGN_PATTERN")

if [ -n "$MATCHES" ]; then
    MATCH_COUNT=$(echo "$MATCHES" | wc -l)
    # Truncated because Telegram rejects messages longer than 4096 characters
    MESSAGE="$(hostname) Found $MATCH_COUNT suspicious line(s) in the standard log:\n\n$LOG_FILE\n\n$(echo "$MATCHES" | head -n 20)"
    $script_dir/send_telegram_alert.sh "$MESSAGE"
    exit 1
fi

echo "Standard log looks clean"
exit 0
