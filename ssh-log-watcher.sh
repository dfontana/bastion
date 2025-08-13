#!/bin/sh
#
# Place this file at: /usr/local/bin/ssh-log-watcher.sh
# Purpose:
#     Tail ssh auth logs and call notify.sh on Accepted/Failed lines.

# Check if ripgrep is available
command -v rg >/dev/null 2>&1 || { echo "ripgrep (rg) is required but not found. Please install it." >&2; exit 1; }

NOTIFY_CMD="${NOTIFY_CMD:-/usr/local/bin/notify.sh}"
LOGFILE="/var/log/auth.log"

process_line() {
  line="$1"

  # Quick filter for likely ssh messages to reduce work
  case "$line" in
    *sshd*Accepted*|*sshd*Failed*|*sshd*Invalid*|*sshd*authentication*)
      ;;
    *)
      return 0
      ;;
  esac

  case "$line" in
    *"Accepted "*)
      user=$(printf '%s\n' "$line" | rg -o '.* for ([^ ]*).*' -r '$1' 2>/dev/null)
      ip=$(printf '%s\n' "$line" | rg -o '.* from ([^ ]*).*' -r '$1' 2>/dev/null)
      port=$(printf '%s\n' "$line" | rg -o '.* port ([0-9]*).*' -r '$1' 2>/dev/null)
      "$NOTIFY_CMD" -s accepted -u "${user:-unknown}" -i "${ip:-unknown}" -p "${port:-0}" -l "$line"
      ;;

    *"Failed "*|*"Invalid user "*|*"authentication failure"*)
      # Try multiple patterns for user extraction
      user=$(printf '%s\n' "$line" | rg -o '(.* for invalid user ([^ ]*).*)|(.* for ([^ ]*).*)|(.*Invalid user ([^ ]*).*)|(.*user=([^ ]*).*)' -r '$2$4$6$8' 2>/dev/null | head -1)
      # Try multiple patterns for IP extraction  
      ip=$(printf '%s\n' "$line" | rg -o '(.* from ([^ ]*).*)|(.*rhost=([^ ]*).*)' -r '$2$4' 2>/dev/null | head -1)
      port=$(printf '%s\n' "$line" | rg -o '.* port ([0-9]*).*' -r '$1' 2>/dev/null)
      "$NOTIFY_CMD" -s failed -u "${user:-unknown}" -i "${ip:-unknown}" -p "${port:-0}" -l "$line"
      ;;

    *) 
      # ignore other lines
      ;;
  esac
}

DEBUG=${DEBUG:-0}
if [ "$DEBUG" -eq 1 ]; then
  # Debug mode: read from stdin for testing
  while IFS= read -r line; do
    process_line "$line"
  done
else
  # Production mode: check for log file and tail it
  if [ ! -f "$LOGFILE" ]; then
    echo "No auth log found. Exiting." >&2
    exit 1
  fi
  # Use tail -F so rotation is handled. Start from new lines only.
  tail -n0 -F "$LOGFILE" 2>/dev/null | \
  while IFS= read -r line; do
    process_line "$line" &
  done
fi
