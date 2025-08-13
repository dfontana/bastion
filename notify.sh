#!/bin/sh
#
# /usr/local/bin/notify.sh
# Send a notification to a Discord webhook
#
# FLAGS:
#   -s status (accepted|failed)
#   -u user
#   -i ip
#   -p port
#   -l raw log line
#
# ENV_ARGS:
#   DEBUG=1      = echo the body, don't send webhook
#   WEBHOOK=".." = Discord webhook URL to post to.

while getopts "s:u:i:p:l:" opt; do
  case $opt in
    s) status="$OPTARG";;
    u) FROM_USER="$OPTARG";;
    i) FROM_IP="$OPTARG";;
    p) FROM_PORT="$OPTARG";;
    l) LOG_LINE="$OPTARG";;
    *) echo "Usage: $0 -s status -u user -i ip -p port -l logline" >&2; exit 1;;
  esac
done

for var in status FROM_USER FROM_IP FROM_PORT LOG_LINE; do
  eval "[ -z \"\$$var\" ]" && echo "Missing ${var}" && exit 1
done

[ "$status" != "accepted" ] && [ "$status" != "failed" ] && echo "Status must be 'accepted' or 'failed'" && exit 1

if [ -z "$WEBHOOK_URL" ]; then
  echo "Missing webhook URL, set env var"
  exit 1
fi
URL="$WEBHOOK_URL?wait=true"

COLOR_OK=65520
COLOR_ALERT=16711680

if [ "$status" = 'accepted' ]; then
  COLOR=$COLOR_ALERT
  MENTION='@here'
else
  COLOR=$COLOR_OK
  MENTION=''
fi

BODY=$(
  jq -cn \
  --arg logLine "\`$LOG_LINE\`" \
  --arg user "$FROM_USER" \
  --arg ip "\`$FROM_IP\`" \
  --arg port "$FROM_PORT" \
  --argjson color $COLOR \
  --arg title "SSH Auth: __**$status**__" \
  --arg mention "$MENTION" \
  '{
    "content": $mention,
    "embeds": [
      {
        "title": $title,
        "description": $logLine,
        "color": $color,
        "fields": [
          {"name": "User","value": $user,"inline": true},
          {"name": "IP","value": $ip,"inline": true},
          {"name": "Port","value": $port,"inline": true}
        ]
      }
    ],
    "components": [],
    "actions": {},
    "flags": 0
  }'
)

DEBUG=${DEBUG:-0}
if [ "$DEBUG" -eq 1 ]; then
  echo "$BODY" | jq
  exit 0
fi

curl -fs -H "Content-Type: application/json" \
-X POST \
-d "$BODY" \
"$URL" > /dev/null
