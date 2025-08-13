# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Testing
- Run unit tests with 'bats tests/**/*.sh'. Specific tests can be ran by providing a more specific file path. Test _cases_ can be isolated by supplying '-f' and a regex for the test name
- Tests are written using BATS (Bash Automated Testing System)
- Dependencies: jq, rg (ripgrep), curl

## System Architecture

This is a defensive security toolkit for SSH bastion hosts containing three main components:

### SSH Authentication Log Watcher (`ssh-log-watcher.sh`)
- Monitors `/var/log/auth.log` in real-time using `tail -F`
- Parses SSH authentication events (accepted/failed/invalid user attempts)
- Sends Discord notifications via webhook for security events
- Uses ripgrep for efficient log parsing with regex patterns
- Runs as a background service to continuously monitor SSH activity

### Dynamic DNS Updater (`ddns/porkbun-ddns.sh`)
- Updates DNS A records via Porkbun API when public IP changes
- Fetches credentials from systemd credentials store for security
- Supports retry logic with exponential backoff
- Validates IP addresses and DNS responses
- Can be run as systemd timer for periodic updates
- Usage: `porkbun-ddns.sh <domain> <subdomain> <ttl>`

### Discord Notification System (`notify.sh`)
- Sends formatted Discord webhook notifications for SSH events
- Accepts status (accepted/failed), user, IP, port, and raw log line
- Uses jq for JSON formatting of Discord embed messages
- Color-codes notifications (green for failed, red for accepted connections)
- Supports debug mode via DEBUG=1 environment variable

## Configuration Files

### systemd Services
- `ddns/porkbun-ddns.service`: systemd service template for DDNS updates
- `ddns/porkbun-ddns.timer`: systemd timer for periodic DDNS checks (30min intervals)
- `ssh-log-watcher`: RC service script for Alpine Linux

### SSH Configuration
- `sshd_config`: Hardened SSH daemon configuration for bastion use

## Security Design
- Credentials stored in systemd credentials store (not files)
- Input validation on all user-provided data
- No secrets in code or logs
- Defensive parsing of authentication logs
- Rate limiting and retry logic for external API calls
