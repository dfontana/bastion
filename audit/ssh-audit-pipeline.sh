#! /bin/bash
#
# Assumes: Installed to same directory as dependency scripts

LOGFILE="/var/log/auth.log"

if [ ! -f "$LOGFILE" ]; then
  echo "No auth log found. Exiting." >&2
  exit 1
fi

# Use tail -F so rotation is handled. Start from new lines only.
tail -n0 -F "$LOGFILE" 2>/dev/null \
| while IFS= read -r line; do
  ./ssh-parse-logins.sh  <<< "$line" \
  | ./discord-ssh-message.sh \
  | ./discord-notify.sh
done
