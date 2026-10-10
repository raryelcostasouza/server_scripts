#!/bin/bash

# See check_partition_disk_usage.sh for why vars_logging.sh is not sourced here: this runs
# hourly so a filling partition is caught within the hour instead of up to a week later.

script_dir="$(dirname "$(readlink -f "$0")")"

$script_dir/../lib/monitor_disk_usage.sh 80 /boot /dev/mapper/vg00-lv01

