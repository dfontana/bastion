#!/bin/bash

# Dynamic DNS Update Script for Porkbun API
# Usage: ./porkbun-ddns.sh <domain> <subdomain> <ttl>
# Example: ./porkbun-ddns.sh example.com home 300
# TODO: This file needs closer code review

set -euo pipefail

# Configuration
readonly PORKBUN_API_BASE="https://porkbun.com/api/json/v3"

# Default values
readonly DEFAULT_TTL=300
readonly MAX_RETRIES=2
readonly RETRY_DELAY=${RETRY_DELAY:-5}

# Configurable commands (for testing)
CURL_FUNC=${CURL_FUNC:-curl}
SYSTEMD_CREDS_FUNC=${SYSTEMD_CREDS_FUNC:-systemd-creds}

# Usage information
usage() {
    cat << EOF
Usage: <domain> <subdomain> <ttl>

Arguments:
  domain     The root domain (e.g., example.com)
  subdomain  The subdomain to update (e.g., home, www, @)
  ttl        DNS TTL in seconds (default: $DEFAULT_TTL)

Examples:
  example.com home 300
  example.com @ 600
EOF
}

# TODO: These log functions might be a problem
log_err() { echo "$1" >&2; }
log() { echo "$1" >&2; }

# Validate IP address format
validate_ip() {
    local ip="$1"
    
    # Check if IP is empty
    if [[ -z "$ip" ]]; then
        return 1
    fi
    
    # Check basic format
    if ! [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 1
    fi
    
    # Check each octet is in valid range (0-255)
    IFS='.' read -ra octets <<< "$ip"
    for octet in "${octets[@]}"; do
        if [[ $octet -gt 255 ]]; then
            return 1
        fi
    done
    
    return 0
}

# Fetch credentials from systemd-credentials only
fetch_credentials() {
    local api_key=""
    local api_secret=""
    
    # Use systemd credentials
    if ! command -v "$SYSTEMD_CREDS_FUNC" >/dev/null 2>&1; then
        log_err "systemd-creds command not found"
        return 1
    fi
    
    if ! api_key=$($SYSTEMD_CREDS_FUNC cat porkbun-api-key 2>/dev/null); then
        log_err "Failed to load porkbun-api-key from systemd credentials"
        return 1
    fi
    
    if ! api_secret=$($SYSTEMD_CREDS_FUNC cat porkbun-api-secret 2>/dev/null); then
        log_err "Failed to load porkbun-api-secret from systemd credentials"
        return 1
    fi
    
    if [[ -z "$api_key" || -z "$api_secret" ]]; then
        log_err "Empty API credentials from systemd"
        return 1
    fi
    
    echo "$api_key:$api_secret"
}

# Get public IP address
get_public_ip() {
    local ip_services
    
    ip_services=(
        "https://ipv4.icanhazip.com"
        "https://ip4.seeip.org"
        "https://ipinfo.io/ip"
        "https://api.ipify.org"
    )
    
    for service in "${ip_services[@]}"; do
        if ip=$($CURL_FUNC -s --max-time 10 "$service" 2>/dev/null); then
            if validate_ip "$ip"; then
                echo "$ip"
                return 0
            fi
        fi
        log "Failed to get IP from $service"
    done
    
    log_err "Failed to get public IP address from all services" 
    return 1
}

# Get current DNS record via Porkbun API
get_dns_record() {
    local domain="$1"
    local subdomain="$2"
    local credentials="$3"
    
    local endpoint="/dns/retrieveByNameType/$domain/A/$subdomain"
    local response
    
    if ! response=$(porkbun_api_request "$endpoint" "POST" "" "$credentials"); then
        log_err "Failed to retrieve DNS record from Porkbun API"
        return 1
    fi
    
    # Check if API request was successful
    if ! echo "$response" | jq -e '.status == "SUCCESS"' >/dev/null 2>&1; then
        local error_msg
        error_msg=$(echo "$response" | jq -r '.message // "Unknown error"' 2>/dev/null || echo "Unknown error")
        log_err "API request failed: $error_msg"
        return 1
    fi
    
    # Count the number of records
    local record_count
    if ! record_count=$(echo "$response" | jq -r '.records | length' 2>/dev/null); then
        log_err "Failed to parse API response"
        return 1
    fi
    
    # Ensure exactly one record exists
    if [[ "$record_count" -eq 0 ]]; then
        log_err "No DNS record found"
        return 1
    elif [[ "$record_count" -gt 1 ]]; then
        log_err "Multiple DNS records found"
        return 1
    fi
    
    # Extract the IP address from the single record
    local current_ip
    if ! current_ip=$(echo "$response" | jq -r '.records[0].content' 2>/dev/null); then
        log_err "Failed to extract IP from DNS record"
        return 1
    fi
    
    echo "$current_ip"
    return 0
}

# Make Porkbun API request
porkbun_api_request() {
    local endpoint="$1"
    local method="$2"
    local data="$3"
    local credentials="$4"
    
    local api_key="${credentials%%:*}"
    local api_secret="${credentials##*:}"
    
    local url="$PORKBUN_API_BASE$endpoint"
    local auth_data="{\"apikey\":\"$api_key\",\"secretapikey\":\"$api_secret\""
    
    if [[ -n "$data" ]]; then
        auth_data="${auth_data},$data"
    fi
    auth_data="${auth_data}}"
    
    local response
    response=$($CURL_FUNC -s -X "$method" \
        -H "Content-Type: application/json" \
        -d "$auth_data" \
        "$url" 2>/dev/null)
    
    if [[ -z "$response" ]]; then
        log_err "Empty response from Porkbun API"
        return 1
    fi
    
    echo "$response"
}

# Update DNS record via Porkbun API
update_dns_record() {
    local domain="$1"
    local subdomain="$2"
    local new_ip="$3"
    local ttl="$4"
    local credentials="$5"
    
    local endpoint="/dns/editByNameType/$domain/A/$subdomain"
    
    local data="\"content\":\"$new_ip\",\"ttl\":\"$ttl\""
    local response
    
    for ((i=1; i<=MAX_RETRIES; i++)); do
        log "API request attempt $i/$MAX_RETRIES"
        
        if response=$(porkbun_api_request "$endpoint" "POST" "$data" "$credentials"); then
            # Check if request was successful
            if echo "$response" | jq -e '.status == "SUCCESS"' >/dev/null 2>&1; then
                log "Successfully updated DNS record for $subdomain.$domain to $new_ip"
                return 0
            else
                local error_msg
                error_msg=$(echo "$response" | jq -r '.message // "Unknown error"' 2>/dev/null || echo "Unknown error")
                log_err "API request failed: $error_msg"
            fi
        else
            log_err "Failed to make API request (attempt $i/$MAX_RETRIES)"
        fi
        
        if [[ $i -lt $MAX_RETRIES ]]; then
            log "Retrying in $RETRY_DELAY seconds..." 
            sleep "$RETRY_DELAY"
        fi
    done
    
    return 1
}

# Main function
main() {
    # Parse arguments
    if [[ $# -lt 2 || $# -gt 3 ]]; then
        usage
        exit 1
    fi
    
    local domain="$1"
    local subdomain="$2"
    local ttl="${3:-$DEFAULT_TTL}"
    
    # Validate subdomain format (only alphabetic characters)
    if ! [[ "$subdomain" =~ ^[a-zA-Z]+$ ]]; then
        log_err "Invalid subdomain: $subdomain (must contain only alphabetic characters)"
        exit 1
    fi
  
    # Validate TTL
    if ! [[ "$ttl" =~ ^[0-9]+$ ]] || [[ $ttl -lt 60 ]] || [[ $ttl -gt 86400 ]]; then
        log_err "Invalid TTL: $ttl (must be between 60 and 86400)"
        exit 1
    fi
    
    log "Starting DNS update check for $subdomain.$domain"
    
    # Check for required commands
    if ! command -v "jq" >/dev/null 2>&1; then
        log_err "jq command not found - required for JSON parsing"
        exit 1
    fi
    
    # Fetch credentials
    local credentials
    if ! credentials=$(fetch_credentials); then
        exit 1
    fi
    
    # Get current public IP
    local public_ip
    if ! public_ip=$(get_public_ip); then
        exit 1
    fi
    
    if ! validate_ip "$public_ip"; then
        log_err "Invalid public IP format: $public_ip"
        exit 1
    fi
    
    log "Current public IP: $public_ip"
    
    # Get current DNS record
    local current_ip
    current_ip=$(get_dns_record "$domain" "$subdomain" "$credentials") || current_ip=""
    
    if [[ -n "$current_ip" ]]; then
        log "Current DNS IP: $current_ip"
        
        if [[ "$current_ip" == "$public_ip" ]]; then
            log "DNS record is already up to date"
            exit 0
        fi
    else
        log "No existing DNS record found"
    fi
    
    # Update DNS record
    if update_dns_record "$domain" "$subdomain" "$public_ip" "$ttl" "$credentials"; then
        log "DNS update completed successfully"
        exit 0
    else
        log_err "Failed to update DNS record"
        exit 1
    fi
}

# Only run main if script is executed directly (not sourced for testing)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
