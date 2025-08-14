#!/bin/bash
#
# Purpose:
#     Parse ssh logs for any authentication attempts

# Check if dependencies available
command -v rg >/dev/null 2>&1 || { echo "ripgrep (rg) is required but not found. Please install it." >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required but not found. Please install it." >&2; exit 1; }

IFS= read -r line
if [ -z "$line" ]; then
  exit 0
fi

case "$line" in
  *"Accepted "*)
    user=$(printf '%s\n' "$line" | rg -o '.* for ([^ ]*).*' -r '$1' 2>/dev/null)
    ip=$(printf '%s\n' "$line" | rg -o '.* from ([^ ]*).*' -r '$1' 2>/dev/null)
    port=$(printf '%s\n' "$line" | rg -o '.* port ([0-9]*).*' -r '$1' 2>/dev/null)
    jq -cn \
      --arg status 'accepted' \
      --arg user "${user:-unknown}" \
      --arg ip "${ip:-unknown}" \
      --arg port "${port:-0}" \
      --arg logLine "$line" \
      '{status:$status,user:$user,ip:$ip,port:$port,logLine:$logLine}'
    ;;

  *"Failed "*|*"Invalid user "*|*"authentication failure"*)
    # Try multiple patterns for user extraction
    user=$(printf '%s\n' "$line" | rg -o '(.* for invalid user ([^ ]*).*)|(.* for ([^ ]*).*)|(.*Invalid user ([^ ]*).*)|(.*user=([^ ]*).*)' -r '$2$4$6$8' 2>/dev/null | head -1)
    # Try multiple patterns for IP extraction  
    ip=$(printf '%s\n' "$line" | rg -o '(.* from ([^ ]*).*)|(.*rhost=([^ ]*).*)' -r '$2$4' 2>/dev/null | head -1)
    port=$(printf '%s\n' "$line" | rg -o '.* port ([0-9]*).*' -r '$1' 2>/dev/null)
    jq -cn \
      --arg status 'failed' \
      --arg user "${user:-unknown}" \
      --arg ip "${ip:-unknown}" \
      --arg port "${port:-0}" \
      --arg logLine "$line" \
      '{status:$status,user:$user,ip:$ip,port:$port,logLine:$logLine}'
    ;;

  *) 
    # ignore other lines
    ;;
esac
