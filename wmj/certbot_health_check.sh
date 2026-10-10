#!/bin/bash

# Alerts while there is still time to act when Let's Encrypt renewal is broken. A failed
# renewal is silent: the site keeps working until the certificate expires and then every
# browser refuses to open it.
#
# The previous version only printed its findings to the standard log, which
# check_if_error_log_not_empty.sh never reads, so a broken renewal raised no alert.

script_dir="$(dirname "$(readlink -f "$0")")"
source "$script_dir/../lib/vars_logging.sh"

# cron runs with a minimal PATH and certbot is often installed as a snap
PATH="$PATH:/usr/local/bin:/snap/bin"

# Certificates are renewed with 30 days left, so this is only reached after more than a
# week of failed attempts
WARNING_DAYS=21
LIVE_DIR="/etc/letsencrypt/live"
CONNECT_TIMEOUT=15

PROBLEMS=""

add_problem() {
    PROBLEMS="$PROBLEMS$1\n\n"
}

alert() {
    $script_dir/../lib/send_telegram_alert.sh "$(hostname) Warning:\n\n$1"
}

# Days left on the PEM certificate read from stdin
days_until_expiry() {
    local END_DATE END_EPOCH
    END_DATE=$(openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
    [ -z "$END_DATE" ] && return 1
    END_EPOCH=$(date -d "$END_DATE" +%s 2>/dev/null) || return 1
    echo $(( (END_EPOCH - $(date +%s)) / 86400 ))
}

printf "\n\n"
echo "Checking certbot and certificate expiry"

$script_dir/../lib/check_required_commands.sh certbot openssl || exit 3

# A broken Python environment after an OS upgrade makes every renewal fail, and the only
# visible symptom is certbot itself refusing to run
CERTBOT_VERSION=$(certbot --version 2>&1)
if [ $? -ne 0 ]; then
    add_problem "certbot cannot run, so no certificate can be renewed:\n$CERTBOT_VERSION"
else
    echo "$CERTBOT_VERSION"
fi

# Renewal is driven by a systemd timer or a cron entry; without one nothing ever runs
if ! systemctl is-active --quiet certbot.timer 2>/dev/null &&
    ! systemctl is-active --quiet snap.certbot.renew.timer 2>/dev/null &&
    [ ! -f /etc/cron.d/certbot ] &&
    ! crontab -l 2>/dev/null | grep -q certbot; then
    add_problem "No renewal schedule is active: certbot.timer and snap.certbot.renew.timer are not running and there is no certbot cron entry. Certificates will expire without being renewed."
fi

CERT_FOUND=0
for CERT_FILE in "$LIVE_DIR"/*/cert.pem; do
    [ -f "$CERT_FILE" ] || continue
    CERT_FOUND=1

    FILE_DAYS=$(days_until_expiry <"$CERT_FILE")
    if [ -z "$FILE_DAYS" ]; then
        add_problem "$CERT_FILE could not be read, so its expiry date is unknown."
        continue
    fi

    DOMAIN=$(openssl x509 -noout -subject -in "$CERT_FILE" 2>/dev/null | sed -n 's/.*CN *= *//p' | cut -d, -f1)
    [ -z "$DOMAIN" ] && DOMAIN=$(basename "$(dirname "$CERT_FILE")")

    echo "$DOMAIN: the certificate on disk expires in $FILE_DAYS days."

    if [ "$FILE_DAYS" -lt "$WARNING_DAYS" ]; then
        add_problem "The certificate for $DOMAIN expires in $FILE_DAYS days and has not been renewed. Run \"certbot renew\" and check /var/log/letsencrypt/letsencrypt.log."
    fi

    # The served certificate can be older than the one on disk when the renewal succeeded
    # but the web server was never reloaded
    SERVED_DAYS=$(echo | timeout "$CONNECT_TIMEOUT" openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" 2>/dev/null | days_until_expiry)

    # An unreachable host is left to monitor_website_health.sh, which runs every 15 minutes
    if [ -z "$SERVED_DAYS" ]; then
        echo "$DOMAIN: the served certificate could not be read, skipping."
        continue
    fi

    echo "$DOMAIN: the served certificate expires in $SERVED_DAYS days."

    if [ "$SERVED_DAYS" -lt "$WARNING_DAYS" ]; then
        DETAILS="The certificate served by $DOMAIN expires in $SERVED_DAYS days."
        # More than a day apart means the renewed file never reached the running server
        if [ "$FILE_DAYS" -gt $((SERVED_DAYS + 1)) ]; then
            DETAILS="$DETAILS The file on disk is valid for $FILE_DAYS days, so the web server is still serving the old certificate and needs to be reloaded."
        fi
        add_problem "$DETAILS"
    fi
done

if [ "$CERT_FOUND" -eq 0 ]; then
    add_problem "No certificate was found under $LIVE_DIR. Either certbot is not managing any certificate on this host, or the directory is not readable."
fi

# Catches an expired account, a broken plugin or a failing challenge before the next real
# renewal depends on it
DRY_RUN_OUTPUT=$(certbot renew --dry-run 2>&1)
if [ $? -ne 0 ]; then
    # Truncated because Telegram rejects messages over 4096 characters
    add_problem "A renewal dry run failed, so the next real renewal will fail too:\n$(printf '%s\n' "$DRY_RUN_OUTPUT" | tail -n 15)"
else
    echo "Renewal dry run successful."
fi

if [ -n "$PROBLEMS" ]; then
    alert "$PROBLEMS"
    exit 3
fi

echo "Certbot is functioning properly."
$script_dir/../lib/check_if_error_log_not_empty.sh $ERROR_LOG_FILE
exit 0