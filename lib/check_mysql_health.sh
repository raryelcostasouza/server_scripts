#!/bin/bash

# Alerts when the database server is up as a systemd unit but not actually usable, and
# once more when it recovers.
#
# "systemctl is-active mariadb" stays green while the server refuses connections because
# max_connections is exhausted, the tmpdir is full or a table is corrupt, which is exactly
# what visitors see as "Error establishing a database connection".
#
# Credentials come from ~/.my.cnf, the same way the backup and requirements checks read them.
#
# vars_logging.sh is deliberately not sourced: this runs at a short cron cadence and
# would otherwise leave dozens of log files a day in ~/server_scripts_logs.

script_dir="$(dirname "$(readlink -f "$0")")"

if [ "$#" -gt 1 ]; then
    echo "Usage: $0 [database]"
    exit 1
fi

DATABASE="$1"

# Connections above this share of max_connections mean the next visitor may be refused
CONNECTION_THRESHOLD_PERCENT=80
CONNECT_TIMEOUT=10

STATE_DIR="$HOME/server_scripts_logs"
"$script_dir/create_logs_dir.sh" >/dev/null

# Does not end in .log, so clean_script_logs_older_n_days.sh leaves it alone
DOWN_MARKER="$STATE_DIR/mysql-health.$(printf '%s' "${DATABASE:-server}" | tr -c '[:alnum:]._-' '_').down"

alert() {
    "$script_dir/send_telegram_alert.sh" "$1"
}

PROBLEMS=""

add_problem() {
    PROBLEMS="$PROBLEMS$1\n\n"
}

if ! command -v mysql >/dev/null 2>&1; then
    add_problem "The mysql client is not available, so database health is not being monitored."
else
    PING_OUTPUT=$(mysql --connect-timeout="$CONNECT_TIMEOUT" -N -B -e 'SELECT 1;' 2>&1)
    if [ $? -ne 0 ] || [ "$PING_OUTPUT" != "1" ]; then
        add_problem "The database server is not answering queries:\n$PING_OUTPUT"
    else
        # Thread and connection counters only make sense once a connection works
        THREADS=$(mysql --connect-timeout="$CONNECT_TIMEOUT" -N -B -e "SHOW GLOBAL STATUS LIKE 'Threads_connected';" 2>/dev/null | awk '{print $2}')
        MAX_CONNECTIONS=$(mysql --connect-timeout="$CONNECT_TIMEOUT" -N -B -e "SHOW GLOBAL VARIABLES LIKE 'max_connections';" 2>/dev/null | awk '{print $2}')

        if [[ "$THREADS" =~ ^[0-9]+$ ]] && [[ "$MAX_CONNECTIONS" =~ ^[0-9]+$ ]] && [ "$MAX_CONNECTIONS" -gt 0 ]; then
            USED_PERCENT=$(( THREADS * 100 / MAX_CONNECTIONS ))
            echo "Connections: $THREADS of $MAX_CONNECTIONS (${USED_PERCENT}%)"
            if [ "$USED_PERCENT" -ge "$CONNECTION_THRESHOLD_PERCENT" ]; then
                add_problem "$THREADS of $MAX_CONNECTIONS connections are in use (${USED_PERCENT}%). New visitors are close to being refused a connection."
            fi
        fi

        # A reachable server with an empty or unreadable site database still means a broken site
        if [ -n "$DATABASE" ]; then
            TABLE_COUNT=$(mysql --connect-timeout="$CONNECT_TIMEOUT" -N -B -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$DATABASE';" 2>&1)
            if ! [[ "$TABLE_COUNT" =~ ^[0-9]+$ ]]; then
                add_problem "The database $DATABASE could not be queried:\n$TABLE_COUNT"
            elif [ "$TABLE_COUNT" -eq 0 ]; then
                add_problem "The database $DATABASE has no tables, so the site cannot work."
            else
                echo "$DATABASE has $TABLE_COUNT tables."
            fi
        fi
    fi
fi

if [ -z "$PROBLEMS" ]; then
    # Only alerts when the server was previously marked down, so a healthy run stays quiet
    if [ -f "$DOWN_MARKER" ]; then
        alert "$(hostname) The database server is healthy again."
        rm -f "$DOWN_MARKER"
    fi
    echo "Database server is healthy."
    exit 0
fi

# Throttled with a marker file, otherwise a lasting failure alerts on every run
if [ ! -f "$DOWN_MARKER" ]; then
    alert "$(hostname) Warning:\n\n$PROBLEMS"
    touch "$DOWN_MARKER"
fi

echo "Database problems found."
exit 3
