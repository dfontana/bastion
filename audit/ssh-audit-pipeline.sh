#! /bin/bash
#
# Assumes: Installed to same directory as dependency scripts

LOGFILE="/var/log/auth.log"

if [ ! -f "$LOGFILE" ]; then
  echo "No auth log found. Exiting." >&2
  exit 1
fi

# Use tail -F so rotation is handled. Start from new lines only.
# TODO: May need to loop over tail w/ | while IFS= read -r line; do
#       to ensure pipeline runs 1x per log line
tail -n0 -F "$LOGFILE" 2>/dev/null  \
 | ./ssh-parse-logins.sh \
 | ./discord-ssh-message.sh \
 | ./discord-notify.sh

