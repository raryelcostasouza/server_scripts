#!/bin/bash

script_dir="$(dirname "$(readlink -f "$0")")"

# Get the script's full path
SCRIPT_PATH=$(realpath "$0")

# Get just the script's file name
SCRIPT_NAME=$(basename "$SCRIPT_PATH")

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

$script_dir/../lib/create_logs_dir.sh
STANDARD_LOG_FILE="~/server_scripts_logs/"$SCRIPT_NAME"-"$TIMESTAMP".log"
ERROR_LOG_FILE="~/server_scripts_logs/"$SCRIPT_NAME"-"$TIMESTAMP".error.log"

#redirecting all output to log file and error output to separate file
exec >$STANDARD_LOG_FILE 2>$ERROR_LOG_FILE