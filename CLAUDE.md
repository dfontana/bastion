# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Testing
- Run unit tests with 'bats tests/**/*.sh'. Specific tests can be ran by providing a more specific file path. Test _cases_ can be isolated by supplying '-f' and a regex for the test name
- Tests are written using BATS (Bash Automated Testing System)
- Dependencies: jq, rg (ripgrep), curl

## System Architecture

This is a defensive security toolkit for SSH bastion hosts with modular components:

### SSH Authentication Monitoring Pipeline
The SSH monitoring system is composed of several modular scripts that work together:

#### SSH Audit Pipeline (`audit/ssh-audit-pipeline.sh`)
- Main orchestration script that monitors `/var/log/auth.log` in real-time using `tail -F`
- Pipes log entries through a processing pipeline of specialized scripts
- Starts from new lines only to avoid processing historical logs
- Runs as a background service to continuously monitor SSH activity

#### SSH Log Parser (`audit/ssh-parse-logins.sh`) 
- Parses SSH authentication events (accepted/failed/invalid user attempts)
- Uses ripgrep for efficient log parsing with regex patterns
- Extracts user, IP, port information from log lines
- Outputs structured JSON for downstream processing

#### Discord Message Formatter (`audit/discord-ssh-message.sh`)
- Transforms parsed SSH event JSON into Discord webhook message format
- Validates all required fields (status, user, IP, port, logLine)
- Creates formatted Discord embed messages with color coding
- Fails fast if any required data is missing

#### Discord Notification Sender (`audit/discord-notify.sh`)
- Sends formatted Discord webhook notifications for SSH events
- Reads message bodies from stdin and posts to Discord webhook
- Requires WEBHOOK_URL environment variable
- Handles HTTP POST requests with proper error handling

### Dynamic DNS Updater (`ddns/porkbun-ddns.sh`)
- Updates DNS A records via Porkbun API when public IP changes
- Fetches credentials from systemd credentials store for security
- Supports retry logic with exponential backoff
- Validates IP addresses and DNS responses
- Can be run as systemd timer for periodic updates
- Usage: `porkbun-ddns.sh <domain> <subdomain> <ttl>`

## Configuration Files

### systemd Services
- `ddns/porkbun-ddns.service`: systemd service template for DDNS updates
- `ddns/porkbun-ddns.timer`: systemd timer for periodic DDNS checks (30min intervals)
- `audit/ssh-log-watcher`: RC service script for Alpine Linux SSH monitoring

### SSH Configuration
- `sshd_config`: Hardened SSH daemon configuration for bastion use

## Security Design
- Credentials stored in systemd credentials store (not files)
- Input validation on all user-provided data
- No secrets in code or logs
- Defensive parsing of authentication logs
- Rate limiting and retry logic for external API calls
