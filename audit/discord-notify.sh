#!/bin/bash
#
# Send a notification to a Discord webhook via stdin.
# The streaming in data should be complete message bodies
#
# ENV_ARGS:
#   WEBHOOK=".." = Discord webhook URL to post to.

if [ -z "$WEBHOOK_URL" ]; then
  echo "Missing webhook URL, set env var"
  exit 1
fi
URL="$WEBHOOK_URL?wait=true"

IFS= read -r line
curl -fs -H "Content-Type: application/json" \
-X POST \
-d "$line" \
"$URL" > /dev/null
