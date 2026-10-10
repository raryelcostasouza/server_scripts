#!/bin/bash

script_dir="$(dirname "$(readlink -f "$0")")"

# php8.1-fpm is version-pinned by Debian: the unit name changes with every PHP
# upgrade, and check_service_status.sh alerts when it no longer exists
$script_dir/../lib/monitor_service_status.sh apache2 mariadb fail2ban ufw php8.1-fpm.service maldet.service

# The mariadb unit can be active while the server refuses the connections the site needs,
# which is the "Error establishing a database connection" page visitors get
$script_dir/../lib/check_mysql_health.sh wmj_org_wordpress
