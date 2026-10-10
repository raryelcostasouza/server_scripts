#!/bin/bash

script_dir="$(dirname "$(readlink -f "$0")")"

# Check if the correct number of arguments is provided
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Usage: $0 <wordpress_root> [php_binary]"
    exit 1
fi

WP_ROOT="$1"
# The site is served by php-fpm, so pass the matching CLI binary (php8.1, php8.2, ...)
# whenever the default `php` on the host is a different branch
PHP_BIN="${2:-php}"
VERSION_FILE="$WP_ROOT/wp-includes/version.php"

printf "\n\n"
echo "Checking WordPress version requirements under $WP_ROOT"

if [ ! -r "$VERSION_FILE" ]; then
    $script_dir/send_telegram_alert.sh "$(hostname) Warning:\n\n $VERSION_FILE is missing or unreadable, so the WordPress requirements check cannot run. Confirm the WordPress root path."
    exit 2
fi

# Reads a single-quoted PHP string variable out of wp-includes/version.php
read_core_version() {
    sed -n "s/^[[:space:]]*\\\$$1[[:space:]]*=[[:space:]]*'\\([^']*\\)'.*/\\1/p" "$VERSION_FILE" | head -n 1
}

# Server versions carry suffixes ("8.1.2-1ubuntu2.14", "5.5.5-10.6.18-MariaDB"), and the
# leading numbers are what WordPress itself compares
normalize_version() {
    printf '%s' "$1" | sed 's/^[^0-9]*//; s/[^0-9.].*//'
}

version_lt() {
    [ "$1" = "$2" ] && return 1
    [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n 1)" = "$1" ]
}

# Reads a WordPress file header ("Requires PHP:", "Requires at least:") from the first
# 8 KB, the same window WordPress uses
read_file_header() {
    head -c 8192 "$1" | tr -d '\r' | grep -iE "^[[:space:]*#@/]*$2:" | head -n 1 | sed 's|^[^:]*:[[:space:]]*||' | awk '{print $1}'
}

WP_VERSION=$(read_core_version wp_version)
REQUIRED_PHP=$(normalize_version "$(read_core_version required_php_version)")
REQUIRED_MYSQL=$(normalize_version "$(read_core_version required_mysql_version)")

echo "Installed WordPress: ${WP_VERSION:-unknown}"

ISSUES=""

# The highest requirement across core, plugins and themes is the one that breaks the site
MAX_PHP_REQUIRED="$REQUIRED_PHP"
MAX_PHP_SOURCE="WordPress core $WP_VERSION"

record_requirements() {
    COMPONENT_LABEL="$1"
    COMPONENT_FILE="$2"

    COMPONENT_PHP=$(normalize_version "$(read_file_header "$COMPONENT_FILE" "Requires PHP")")
    COMPONENT_WP=$(normalize_version "$(read_file_header "$COMPONENT_FILE" "Requires at least")")

    if [ -n "$COMPONENT_PHP" ] && version_lt "$MAX_PHP_REQUIRED" "$COMPONENT_PHP"; then
        MAX_PHP_REQUIRED="$COMPONENT_PHP"
        MAX_PHP_SOURCE="$COMPONENT_LABEL"
    fi

    if [ -n "$COMPONENT_WP" ] && [ -n "$WP_VERSION" ] && version_lt "$WP_VERSION" "$COMPONENT_WP"; then
        ISSUES+="$COMPONENT_LABEL requires WordPress $COMPONENT_WP, installed is $WP_VERSION\n"
    fi
}

for PLUGIN_FILE in "$WP_ROOT"/wp-content/plugins/*/*.php; do
    [ -r "$PLUGIN_FILE" ] || continue
    # Only the main plugin file carries the headers
    head -c 8192 "$PLUGIN_FILE" | grep -qiE "^[[:space:]*#@/]*Plugin Name:" || continue
    record_requirements "Plugin $(basename "$(dirname "$PLUGIN_FILE")")" "$PLUGIN_FILE"
done

for THEME_STYLE in "$WP_ROOT"/wp-content/themes/*/style.css; do
    [ -r "$THEME_STYLE" ] || continue
    record_requirements "Theme $(basename "$(dirname "$THEME_STYLE")")" "$THEME_STYLE"
done

echo "Highest PHP requirement: ${MAX_PHP_REQUIRED:-unknown} (from $MAX_PHP_SOURCE)"
echo "Core MySQL requirement: ${REQUIRED_MYSQL:-unknown}"

PHP_VERSION=""
if command -v "$PHP_BIN" >/dev/null 2>&1; then
    PHP_VERSION=$(normalize_version "$("$PHP_BIN" -r 'echo PHP_VERSION;' 2>/dev/null)")
fi

if [ -z "$PHP_VERSION" ]; then
    ISSUES+="Could not determine the PHP version from '$PHP_BIN'\n"
elif [ -n "$MAX_PHP_REQUIRED" ] && version_lt "$PHP_VERSION" "$MAX_PHP_REQUIRED"; then
    ISSUES+="PHP $PHP_VERSION is below $MAX_PHP_REQUIRED, required by $MAX_PHP_SOURCE\n"
else
    echo "Installed PHP: $PHP_VERSION"
fi

DB_VERSION=""
if command -v mysql >/dev/null 2>&1; then
    DB_VERSION=$(normalize_version "$(mysql -N -B -e 'SELECT VERSION();' 2>/dev/null | head -n 1)")
fi

if [ -z "$DB_VERSION" ]; then
    ISSUES+="Could not determine the database server version (mysql client missing or no credentials in ~/.my.cnf)\n"
elif [ -n "$REQUIRED_MYSQL" ] && version_lt "$DB_VERSION" "$REQUIRED_MYSQL"; then
    ISSUES+="Database server $DB_VERSION is below $REQUIRED_MYSQL, required by WordPress core $WP_VERSION\n"
else
    echo "Installed database server: $DB_VERSION"
fi

if [ -n "$ISSUES" ]; then
    $script_dir/send_telegram_alert.sh "$(hostname) Warning:\n\n WordPress requirements are not met at $WP_ROOT:\n\n$ISSUES"
    exit 3
fi

echo "All WordPress requirements are met. No action needed."
exit 0
