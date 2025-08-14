#!/bin/bash
#
# Transforms arugments from ssh-auditing script into a discord message body
# failing if unable to do so

command -v jq >/dev/null 2>&1 || { echo "jq is required but not found. Please install it." >&2; exit 1; }

read -r line
status=$(jq -r '.status' <<< "$line")
user=$(jq -r '.user' <<< "$line")
ip=$(jq -r '.ip' <<< "$line")
port=$(jq -r '.port' <<< "$line")
logLine=$(jq -r '.logLine' <<< "$line")

for var in status user ip port logLine; do
  if [ -z "${!var}" ] || [ "${!var}" = 'null' ]; then
    echo "Missing ${var}"
    exit 1
  fi
done
[ "$status" != 'accepted' ] && [ "$status" != 'failed' ] && echo "Status must be 'accepted' or 'failed'" && exit 1

color_ok=65520
color_alert=16711680

if [ "$status" = 'accepted' ]; then
  color=$color_alert
  mention='@here'
else
  color=$color_ok
  mention=''
fi

jq -cn \
--arg logLine "\`$logLine\`" \
--arg user "$user" \
--arg ip "\`$ip\`" \
--arg port "$port" \
--argjson color $color \
--arg title "SSH Auth: __**$status**__" \
--arg mention "$mention" \
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
