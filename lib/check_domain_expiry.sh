#!/bin/bash

# Alerts when a domain is approaching its registration expiry.
#
# certbot_health_check.sh covers the TLS certificate, but an expired domain registration is
# a worse and completely silent outage: the site, its mail and every link to it stop working
# at once, and nothing on the server logs a thing.

script_dir="$(dirname "$(readlink -f "$0")")"

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Usage: $0 <domain> [warning_days]"
    exit 1
fi

DOMAIN="$1"
# Registrars usually start reminding at 30 days, so this leaves room to act before that
WARNING_DAYS="${2:-45}"

WHOIS_TIMEOUT=30

alert() {
    "$script_dir/send_telegram_alert.sh" "$1"
}

printf "\n\n"
echo "Checking the registration expiry of $DOMAIN"

if ! command -v whois >/dev/null 2>&1; then
    alert "$(hostname) Warning:\n\n whois is not installed, so the registration expiry of $DOMAIN is not being monitored. Install it with \"apt install whois\"."
    exit 2
fi

WHOIS_OUTPUT=$(timeout "$WHOIS_TIMEOUT" whois "$DOMAIN" 2>/dev/null)

if [ -z "$WHOIS_OUTPUT" ]; then
    alert "$(hostname) Warning:\n\n whois returned nothing for $DOMAIN, so its expiry date could not be checked."
    exit 2
fi

# Registries all use a different label for the same field
EXPIRY_RAW=$(printf '%s\n' "$WHOIS_OUTPUT" | grep -iE '^[[:space:]]*(Registry Expiry Date|Registrar Registration Expiration Date|Expiration Date|Expiry Date|Expires On|expire|paid-till)[[:space:]]*:' | head -n 1 | sed 's|^[^:]*:[[:space:]]*||' | tr -d '\r')

if [ -z "$EXPIRY_RAW" ]; then
    alert "$(hostname) Warning:\n\n No expiry date was found in the whois record for $DOMAIN. Check the registration manually."
    exit 2
fi

EXPIRY_EPOCH=$(date -d "$EXPIRY_RAW" +%s 2>/dev/null)
if [ -z "$EXPIRY_EPOCH" ]; then
    alert "$(hostname) Warning:\n\n The expiry date \"$EXPIRY_RAW\" for $DOMAIN could not be parsed. Check the registration manually."
    exit 2
fi

DAYS_LEFT=$(( (EXPIRY_EPOCH - $(date +%s)) / 86400 ))

echo "$DOMAIN expires in $DAYS_LEFT days ($EXPIRY_RAW)."

if [ "$DAYS_LEFT" -lt "$WARNING_DAYS" ]; then
    alert "$(hostname) Warning:\n\n The domain registration for $DOMAIN expires in $DAYS_LEFT days ($EXPIRY_RAW). Renew it with the registrar."
    exit 3
fi

exit 0
