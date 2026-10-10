#!/bin/bash

# Alerts when WordPress core, plugin or theme files differ from the official release, and
# when updates are pending.
#
# maldet matches known malware signatures; it does not notice a backdoor added to a
# legitimate core or plugin file, which is how a compromised WordPress install usually
# looks. Checksums compare every file against wordpress.org and catch exactly that.
# Outdated plugins are the other half: they are the most common way the site gets in.
#
# wp-cli refuses to run as root, and on a host where the site is owned by www-data no
# other user can read wp-config.php. The caller therefore starts this as root and passes
# the site owner, so wp-cli itself is dropped to that user.

script_dir="$(dirname "$(readlink -f "$0")")"

if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
    echo "Usage: $0 <wordpress_root> [wp_cli_binary] [run_as_user]"
    exit 1
fi

WP_ROOT="$1"
WP_CLI="${2:-wp}"
RUN_AS_USER="${3:-}"

PROBLEMS=""
SUMMARY=""

add_problem() {
    PROBLEMS="$PROBLEMS$1\n\n"
}

alert() {
    "$script_dir/send_telegram_alert.sh" "$1"
}

printf "\n\n"
echo "Checking WordPress file integrity and pending updates under $WP_ROOT"

if ! command -v "$WP_CLI" >/dev/null 2>&1; then
    alert "$(hostname) Warning:\n\n wp-cli (\"$WP_CLI\") is not available, so WordPress file integrity is not being monitored. Install it from https://wp-cli.org or pass the binary path as the second argument."
    exit 2
fi

if [ ! -f "$WP_ROOT/wp-includes/version.php" ]; then
    alert "$(hostname) Warning:\n\n $WP_ROOT does not look like a WordPress installation, so the integrity check cannot run. Confirm the WordPress root path."
    exit 2
fi

if [ -n "$RUN_AS_USER" ]; then
    if [ "$(id -u)" -ne 0 ]; then
        alert "$(hostname) Warning:\n\n The WordPress integrity check is configured to run wp-cli as \"$RUN_AS_USER\" but was not started as root, so it cannot drop privileges. Schedule it from root's crontab."
        exit 2
    fi
    if ! command -v runuser >/dev/null 2>&1; then
        alert "$(hostname) Warning:\n\n runuser is not available, so wp-cli cannot be dropped to \"$RUN_AS_USER\" and WordPress file integrity is not being monitored."
        exit 2
    fi
    if ! id "$RUN_AS_USER" >/dev/null 2>&1; then
        alert "$(hostname) Warning:\n\n The user \"$RUN_AS_USER\" does not exist, so the WordPress integrity check cannot run."
        exit 2
    fi
elif [ "$(id -u)" -eq 0 ]; then
    # --allow-root is deliberately not used: it would run site code with full privileges
    alert "$(hostname) Warning:\n\n The WordPress integrity check was started as root without a user to drop to. Pass the site owner as the third argument so wp-cli does not run as root."
    exit 2
fi

# wp-cli keeps its checksum cache under $HOME, and www-data's home is normally not
# writable. A fresh directory also avoids a fixed /tmp path that the web user could
# pre-create as a symlink.
CACHE_DIR=$(mktemp -d) || {
    alert "$(hostname) Warning:\n\n Could not create a temporary directory, so the WordPress integrity check did not run."
    exit 2
}
trap 'rm -rf "$CACHE_DIR"' EXIT

if [ -n "$RUN_AS_USER" ]; then
    chown "$RUN_AS_USER" "$CACHE_DIR"
fi

# wp-config.php sits either in the WordPress root or one level above it
CONFIG_FILE="$WP_ROOT/wp-config.php"
[ -f "$CONFIG_FILE" ] || CONFIG_FILE="$(dirname "$WP_ROOT")/wp-config.php"

# Every command that loads WordPress reads this file first, and an unreadable one surfaces
# as a misleading "Strange wp-config.php file" error
if [ -f "$CONFIG_FILE" ]; then
    if [ -n "$RUN_AS_USER" ]; then
        CONFIG_READABLE=$(runuser -u "$RUN_AS_USER" -- test -r "$CONFIG_FILE" && echo yes)
    else
        CONFIG_READABLE=$([ -r "$CONFIG_FILE" ] && echo yes)
    fi

    if [ "$CONFIG_READABLE" != "yes" ]; then
        alert "$(hostname) Warning:\n\n ${RUN_AS_USER:-$(id -un)} cannot read $CONFIG_FILE, so WordPress cannot be loaded and the integrity check cannot run. Check the owner and permissions of wp-config.php."
        exit 2
    fi
fi

# A broken or malicious plugin must not be able to stop the check that would report it,
# and --skip-plugins/--skip-themes also means no site code is executed during the check
WP=()
[ -n "$RUN_AS_USER" ] && WP+=(runuser -u "$RUN_AS_USER" --)
WP+=(env "HOME=$CACHE_DIR" "WP_CLI_CACHE_DIR=$CACHE_DIR/cache"
    "$WP_CLI" "--path=$WP_ROOT" --skip-plugins --skip-themes --no-color)

# Returns the output of a wp-cli command, or nothing when it fails
run_wp() {
    local OUTPUT
    OUTPUT=$("${WP[@]}" "$@" 2>&1)
    if [ $? -ne 0 ]; then
        printf '%s' "$OUTPUT"
        return 1
    fi
    printf '%s' "$OUTPUT"
}

printf "\n\n"
echo "Verifying core checksums"

CORE_OUTPUT=$(run_wp core verify-checksums)
if [ $? -ne 0 ]; then
    # Truncated because Telegram rejects messages over 4096 characters
    add_problem "WordPress core files do not match the official release:\n$(printf '%s\n' "$CORE_OUTPUT" | grep -v '^Success:' | head -n 15)"
else
    echo "Core checksums verified."
fi

printf "\n\n"
echo "Verifying plugin checksums"

# Only plugins published on wordpress.org can be verified; premium and custom plugins are
# reported as "not found in the checksums" and are not a problem in themselves
PLUGIN_OUTPUT=$(run_wp plugin verify-checksums --all)
if [ $? -ne 0 ]; then
    PLUGIN_ISSUES=$(printf '%s\n' "$PLUGIN_OUTPUT" | grep -iE 'checksum|modified|added|removed' | grep -viE 'not found in the checksums|no checksums' | head -n 15)
    if [ -n "$PLUGIN_ISSUES" ]; then
        add_problem "Plugin files do not match the official release:\n$PLUGIN_ISSUES"
    else
        echo "Only unverifiable (premium or custom) plugins reported, no modified files."
    fi
else
    echo "Plugin checksums verified."
fi

printf "\n\n"
echo "Counting pending updates"

CORE_UPDATES=$(run_wp core check-update --format=count 2>/dev/null)
[[ "$CORE_UPDATES" =~ ^[0-9]+$ ]] || CORE_UPDATES=0

PLUGIN_UPDATES=$(run_wp plugin list --update=available --format=count 2>/dev/null)
[[ "$PLUGIN_UPDATES" =~ ^[0-9]+$ ]] || PLUGIN_UPDATES=0

THEME_UPDATES=$(run_wp theme list --update=available --format=count 2>/dev/null)
[[ "$THEME_UPDATES" =~ ^[0-9]+$ ]] || THEME_UPDATES=0

SUMMARY+="Pending updates: core $CORE_UPDATES, plugins $PLUGIN_UPDATES, themes $THEME_UPDATES\n"

if [ "$CORE_UPDATES" -gt 0 ]; then
    add_problem "A WordPress core update is available. Core updates usually close a security hole that is already public."
fi

if [ "$PLUGIN_UPDATES" -gt 0 ]; then
    PLUGIN_NAMES=$(run_wp plugin list --update=available --field=name 2>/dev/null | tr '\n' ' ')
    add_problem "$PLUGIN_UPDATES plugin update(s) available:\n$PLUGIN_NAMES"
fi

if [ "$THEME_UPDATES" -gt 0 ]; then
    THEME_NAMES=$(run_wp theme list --update=available --field=name 2>/dev/null | tr '\n' ' ')
    add_problem "$THEME_UPDATES theme update(s) available:\n$THEME_NAMES"
fi

if [ -n "$PROBLEMS" ]; then
    alert "$(hostname) Warning:\n\n WordPress needs attention at $WP_ROOT:\n\n$PROBLEMS$SUMMARY"
    exit 3
fi

echo "WordPress files match the official release and everything is up to date."
exit 0
