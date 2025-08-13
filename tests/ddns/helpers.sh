#!/bin/bash

# Test helper functions for porkbun-ddns.sh tests
# These functions use real tools but with controlled test data

# Get the directory containing this script
HELPERS_DIR="$(dirname "${BASH_SOURCE[0]}")"
FIXTURES_DIR="$HELPERS_DIR/fixtures"

# Test curl implementation that reads from fixture files
test_curl() {
    local args=("$@")
    local url=""
    
    # Parse arguments to find the URL
    for arg in "${args[@]}"; do
        if [[ "$arg" =~ ^https?:// ]]; then
            url="$arg"
            break
        fi
    done
    
    # Handle different URL patterns
    case "$url" in
        *"ipv4.icanhazip.com"*|*"ip4.seeip.org"*|*"ipinfo.io/ip"*|*"api.ipify.org"*)
            echo "$TEST_HOST_IP"
            ;;
        *"porkbun.com/api/json/v3/dns/retrieveByNameType/"*)
            cat "$FIXTURES_DIR/$TEST_API_RESPONSE_FILE"
            ;;
        *"porkbun.com/api/json/v3/dns/editByNameType/"*)
            cat "$FIXTURES_DIR/$TEST_UPDATE_RESPONSE_FILE"
            ;;
        *)
            return 1
            ;;
    esac
}

# Test systemd-creds implementation
test_systemd_creds() {
    local command="$1"
    local credential="$2"
    
    if [[ "$command" != "cat" ]]; then
        return 1
    fi
    
    case "$credential" in
        "porkbun-api-key")
            echo "test_key_123"
            ;;
        "porkbun-api-secret")
            echo "test_secret_456"
            ;;
        *)
            return 1
            ;;
    esac
}

setup_test_environment() {
    export CURL_FUNC="test_curl"
    export SYSTEMD_CREDS_FUNC="test_systemd_creds"
}

set_api_response() {
    export TEST_API_RESPONSE_FILE="$1"
}

set_update_response() {
    export TEST_UPDATE_RESPONSE_FILE="$1"
}

set_host_ip() {
    export TEST_HOST_IP="$1"
}

# Helper to reset test state
reset_test_state() {
    unset TEST_API_RESPONSE_FILE
    unset TEST_UPDATE_RESPONSE_FILE
    unset TEST_HOST_IP
}
