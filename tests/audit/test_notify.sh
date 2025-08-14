#!/usr/bin/env bats

setup() {
    export WEBHOOK_URL="https://discord.com/api/webhooks/test"
    export SCRIPT_DIR="${BATS_TEST_DIRNAME}/../../audit"
}

@test "notify.sh requires all arguments" {
    run "$SCRIPT_DIR/notify.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing"* ]]
}

@test "notify.sh requires status argument" {
    run "$SCRIPT_DIR/notify.sh" -u testuser -i 192.168.1.1 -p 22 -l "test log"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing status"* ]]
}

@test "notify.sh requires user argument" {
    run "$SCRIPT_DIR/notify.sh" -s accepted -i 192.168.1.1 -p 22 -l "test log"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing FROM_USER"* ]]
}

@test "notify.sh requires ip argument" {
    run "$SCRIPT_DIR/notify.sh" -s accepted -u testuser -p 22 -l "test log"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing FROM_IP"* ]]
}

@test "notify.sh requires port argument" {
    run "$SCRIPT_DIR/notify.sh" -s accepted -u testuser -i 192.168.1.1 -l "test log"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing FROM_PORT"* ]]
}

@test "notify.sh requires log line argument" {
    run "$SCRIPT_DIR/notify.sh" -s accepted -u testuser -i 192.168.1.1 -p 22
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing LOG_LINE"* ]]
}

@test "notify.sh validates status is accepted or failed" {
    run "$SCRIPT_DIR/notify.sh" -s invalid -u testuser -i 192.168.1.1 -p 22 -l "test log"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Status must be 'accepted' or 'failed'"* ]]
}

@test "notify.sh requires WEBHOOK_URL environment variable" {
    unset WEBHOOK_URL
    run "$SCRIPT_DIR/notify.sh" -s accepted -u testuser -i 192.168.1.1 -p 22 -l "test log"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing webhook URL"* ]]
}

@test "notify.sh generates JSON for accepted status in debug mode" {
    export DEBUG=1
    run "$SCRIPT_DIR/notify.sh" -s accepted -u testuser -i 192.168.1.1 -p 22 -l "SSH connection accepted"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"title": "SSH Auth: __**accepted**__"'* ]]
    [[ "$output" == *'"description": "`SSH connection accepted`"'* ]]
    [[ "$output" == *'"value": "testuser"'* ]]
    [[ "$output" == *'"value": "`192.168.1.1`"'* ]]
    [[ "$output" == *'"value": "22"'* ]]
    [[ "$output" == *'"content": "@here"'* ]]
}

@test "notify.sh generates JSON for failed status in debug mode" {
    export DEBUG=1
    run "$SCRIPT_DIR/notify.sh" -s failed -u baduser -i 10.0.0.1 -p 2222 -l "SSH connection failed"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"title": "SSH Auth: __**failed**__"'* ]]
    [[ "$output" == *'"description": "`SSH connection failed`"'* ]]
    [[ "$output" == *'"value": "baduser"'* ]]
    [[ "$output" == *'"value": "`10.0.0.1`"'* ]]
    [[ "$output" == *'"value": "2222"'* ]]
    [[ "$output" == *'"content": ""'* ]]
}

@test "notify.sh uses correct colors for accepted vs failed" {
    export DEBUG=1
    
    # Test accepted (alert color)
    run "$SCRIPT_DIR/notify.sh" -s accepted -u testuser -i 192.168.1.1 -p 22 -l "test"
    [[ "$output" == *'"color": 16711680'* ]]
    
    # Test failed (ok color)
    run "$SCRIPT_DIR/notify.sh" -s failed -u testuser -i 192.168.1.1 -p 22 -l "test"
    [[ "$output" == *'"color": 65520'* ]]
}

@test "notify.sh handles special characters in log line" {
    export DEBUG=1
    run "$SCRIPT_DIR/notify.sh" -s accepted -u "test user" -i 192.168.1.1 -p 22 -l 'Log with "quotes" and $pecial chars'
    [ "$status" -eq 0 ]
    [[ "$output" == *'Log with \"quotes\" and $pecial chars'* ]]
}
