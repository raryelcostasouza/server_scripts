#!/bin/bash

script_dir="$(dirname "$(readlink -f "$0")")"

# php8.1-fpm is version-pinned by Debian: the unit name changes with every PHP
# upgrade, and check_service_status.sh alerts when it no longer exists
$script_dir/../lib/monitor_service_status.sh apache2 mariadb fail2ban ufw php8.1-fpm.service maldet.service
