#!/usr/bin/env bats

# test/porkbun-ddns.bats
# Unit tests for porkbun-ddns.sh using real tools with fixture data

# Setup and teardown
setup() {
    export RETRY_DELAY=0

    # Source test helpers
    source "${BATS_TEST_DIRNAME}/helpers.sh"
    
    # Source the script for testing
    source "${BATS_TEST_DIRNAME}/../../ddns/porkbun-ddns.sh"
       
    # Setup test environment with real tools
    setup_test_environment
    reset_test_state
}

teardown() {
    reset_test_state
}

# Test credential fetching
@test "fetch_credentials: should get credentials from systemd" {
    run fetch_credentials
    [ "$status" -eq 0 ]
    [ "$output" = "test_key_123:test_secret_456" ]
}

@test "fetch_credentials: should fail when systemd-creds not available" {
    export SYSTEMD_CREDS_FUNC="nonexistent_command_12345"
    
    run fetch_credentials
    [ "$status" -eq 1 ]
    [[ "$output" == *"systemd-creds command not found"* ]]
}

# Test DNS record fetching with various API responses
@test "get_dns_record: should return current IP for valid response" {
    local credentials="test_key_123:test_secret_456"
    set_api_response "porkbun_success.json"
    
    run get_dns_record "example.com" "test" "$credentials"
    [ "$status" -eq 0 ]
    [ "$output" = "192.168.1.50" ]
}

@test "get_dns_record: should fail for API error response" {
    local credentials="test_key_123:test_secret_456"
    set_api_response "porkbun_error.json"
    
    run get_dns_record "example.com" "test" "$credentials"
    [ "$status" -eq 1 ]
    [[ "$output" == *"API request failed: Invalid API credentials"* ]]
}

@test "get_dns_record: should fail for multiple records" {
    local credentials="test_key_123:test_secret_456"
    set_api_response "porkbun_multiple_records.json"
    
    run get_dns_record "example.com" "test" "$credentials"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Multiple DNS records found"* ]]
}

@test "get_dns_record: should fail for empty records" {
    local credentials="test_key_123:test_secret_456"
    set_api_response "porkbun_empty_records.json"
    
    run get_dns_record "example.com" "test" "$credentials"
    [ "$status" -eq 1 ]
    [[ "$output" == *"No DNS record found"* ]]
}

# Test IP validation
@test "validate_ip: should accept valid IPv4 addresses" {
    run validate_ip "192.168.1.1"
    [ "$status" -eq 0 ]
    
    run validate_ip "10.0.0.1"
    [ "$status" -eq 0 ]
    
    run validate_ip "255.255.255.255"
    [ "$status" -eq 0 ]
}

@test "validate_ip: should reject invalid IP addresses" {
    run validate_ip "256.1.1.1"
    [ "$status" -eq 1 ]
    
    run validate_ip "192.168.1"
    [ "$status" -eq 1 ]
    
    run validate_ip "not.an.ip.address"
    [ "$status" -eq 1 ]
    
    run validate_ip ""
    [ "$status" -eq 1 ]
}

# Test Porkbun API requests with real JSON data
@test "porkbun_api_request: should make successful API request" {
    local credentials="test_key_123:test_secret_456"
    local data='"content":"192.168.1.100","ttl":"300"'
    set_update_response "porkbun_update_success.json"
    
    run porkbun_api_request "/dns/editByNameType/example.com/A/test" "POST" "$data" "$credentials"
    [ "$status" -eq 0 ]
    [[ "$output" == *"SUCCESS"* ]]
}

@test "porkbun_api_request: should handle empty response" {
    local credentials="test_key_123:test_secret_456"
    export CURL_FUNC="true"  # Returns empty output
    
    run porkbun_api_request "/dns/editByNameType/example.com/A/test" "POST" "" "$credentials"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Empty response from Porkbun API"* ]]
}

# Test DNS record updates
@test "update_dns_record: should successfully update DNS record" {
    local credentials="test_key_123:test_secret_456"
    set_update_response "porkbun_update_success.json"
    
    run update_dns_record "example.com" "test" "192.168.1.100" "300" "$credentials"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Successfully updated DNS record"* ]]
}

@test "update_dns_record: should handle API errors with retry" {
    local credentials="test_key_123:test_secret_456"
    set_update_response "porkbun_error.json"
    
    run update_dns_record "example.com" "test" "192.168.1.100" "300" "$credentials"
    [ "$status" -eq 1 ]
    [[ "$output" == *"API request failed: Invalid API credentials"* ]]
    # Should show retry attempts
    [[ "$output" == *"API request attempt 1/"* ]]
    [[ "$output" == *"API request attempt 2/"* ]]
}

# Integration tests
@test "main: should display usage when no arguments provided" {
    run main
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "main: should display usage with invalid arguments" {
    run main "example.com"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "main: should reject invalid subdomain format" {
    run main "example.com" "test123" "300"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid subdomain"* ]]
}

@test "main: should reject invalid TTL values" {
    run main "example.com" "test" "invalid"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid TTL"* ]]
    
    run main "example.com" "test" "30"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid TTL"* ]]
    
    run main "example.com" "test" "100000"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid TTL"* ]]
}

@test "main: should exit cleanly when DNS is up to date" {
    set_host_ip "192.168.1.50"
    set_api_response "porkbun_success.json"
    
    run main "example.com" "test" "300"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DNS record is already up to date"* ]]
}

@test "main: should update DNS when IP differs" {
    set_host_ip "192.168.1.100"
    set_api_response "porkbun_success.json"
    set_update_response "porkbun_update_success.json"
    
    run main "example.com" "test" "300"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DNS update completed successfully"* ]]
}

@test "main: should handle missing DNS record" {
    set_host_ip "192.168.1.100"
    set_api_response "porkbun_empty_records.json"
    set_update_response "porkbun_update_success.json"
    
    run main "example.com" "test" "300"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No existing DNS record found"* ]]
    [[ "$output" == *"DNS update completed successfully"* ]]
}

# Security tests
@test "script should handle malicious input safely" {
    # Test with potentially dangerous characters in domain
    run main "example.com; rm -rf /" "test" "300"
    [ "$status" -ne 0 ]
    
    # Test with command injection in subdomain
    run main "example.com" 'test$(evil_command)' "300"
    [ "$status" -ne 0 ]
}
