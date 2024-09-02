#!/bin/bash

script_dir="$(dirname "$(readlink -f "$0")")"
source $script_dir/../lib/vars_logging.sh

$script_dir/../lib/monitor_disk_usage.sh 80 /

