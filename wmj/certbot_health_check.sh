#!/bin/bash

script_dir="$(dirname "$(readlink -f "$0")")"
source "$script_dir/../lib/vars_logging.sh"

# Function to check if certbot is installed and executable
check_certbot_installed() {
    if ! command -v certbot &> /dev/null
    then
        echo "Certbot is not installed or not in your PATH."
        exit 1
    else
        echo "Certbot is installed."
    fi
}

# Function to check certbot version
check_certbot_version() {
    echo "Checking certbot version..."
    certbot_version=$(certbot --version)
    if [[ $? -ne 0 ]]; then
        echo "Error: Unable to retrieve certbot version. Details:"
        echo "$certbot_version"
        exit 1
    else
        echo "Certbot version: $certbot_version"
    fi
}

# Function to run a certbot dry-run
check_certbot_dry_run() {
    echo "Running certbot dry-run test..."
    dry_run_output=$(certbot renew --dry-run)
    if [[ $? -ne 0 ]]; then
        echo "Error: Certbot dry-run failed. Details:"
        echo "$dry_run_output"
        exit 1
    else
        echo "Certbot dry-run successful."
    fi
}

# Function to check for Python dependency issues
check_python_dependencies() {
    echo "Checking for Python dependency errors..."
    python_errors=$(certbot --version | grep -i "traceback\|module\|error\|No module named")
    if [[ -n "$python_errors" ]]; then
        echo "Python dependency errors detected:"
        echo "$python_errors"
        exit 1
    else
        echo "No Python dependency errors found."
    fi
}

# Main script execution
check_certbot_installed
check_certbot_version
check_python_dependencies
check_certbot_dry_run

echo "Certbot is functioning properly."
echo $ERROR_LOG_FILE
$script_dir/../lib/check_if_error_log_not_empty.sh $ERROR_LOG_FILE