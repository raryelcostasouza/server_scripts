#!/bin/bash

script_dir="$(dirname "$(readlink -f "$0")")"
source $script_dir/../creds/telegram.sh

# Check if a message argument was provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <message>"
    exit 1
fi

# Get the message from the argument
MESSAGE="$1"

# Replace newlines in the message with \n for plain text format
FORMATTED_MESSAGE=$(echo -e "$MESSAGE" | sed 's/\n/\\n/g')

curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
         -d "chat_id=$CHAT_ID" \
         -d "text=$FORMATTED_MESSAGE" 
