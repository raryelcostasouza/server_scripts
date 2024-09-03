#!/bin/bash
script_dir="$(dirname "$(readlink -f "$0")")"
source "$script_dir/../../creds/duplicity.sh"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

#duplicity list-current-files -t 10D gdocs://info@watmarpjan.com/WMJ_Server_Backup/WMJ.COM
#duplicity -t 10D --file-to-restore public_html/layp gdocs://info@watmarpjan.com/WMJ_Server_Backup/WMJ.COM /home/pmpanya/bin/old

