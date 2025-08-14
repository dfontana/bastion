#!/usr/bin/env bats

setup() {
    export SCRIPT="${BATS_TEST_DIRNAME}/../../audit/discord-ssh-message.sh"
}

@test "requires all arguments" {
    input='{"status":"accepted"}'
    run bash -c "echo '$input' | $SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing"* ]]
}

@test "requires status argument" {
    input='{"user":"testuser","ip":"192.168.1.1","port":"22","logLine":"test log"}'
    run bash -c "echo '$input' | $SCRIPT" 
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing status"* ]]
}

@test "requires user argument" {
    input='{"status":"accepted","ip":"192.168.1.1","port":"22","logLine":"test log"}'
    run bash -c "echo '$input' | $SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing user"* ]]
}

@test "requires ip argument" {
    input='{"status":"accepted","user":"testuser","port":"22","logLine":"test log"}'
    run bash -c "echo '$input' | $SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing ip"* ]]
}

@test "requires port argument" {
    input='{"status":"accepted","user":"testuser","ip":"192.168.1.1","logLine":"test log"}'
    run bash -c "echo '$input' | $SCRIPT" 
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing port"* ]]
}

@test "requires log line argument" {
    input='{"status":"accepted","user":"testuser","ip":"192.168.1.1","port":"22"}'
    run bash -c "echo '$input' | $SCRIPT" 
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing logLine"* ]]
}

@test "validates status is accepted or failed" {
    input='{"status":"invalid","user":"testuser","ip":"192.168.1.1","port":"22","logLine":"test log"}'
    run bash -c "echo '$input' | $SCRIPT" 
    [ "$status" -eq 1 ]
    [[ "$output" == *"Status must be 'accepted' or 'failed'"* ]]
}

@test "generates JSON for accepted status" {
    input='{"status":"accepted","user":"testuser","ip":"192.168.1.1","port":"22","logLine":"SSH connection accepted"}'
    run bash -c "echo '$input' | $SCRIPT" 
    [ "$status" -eq 0 ]
    [[ "$output" == *'"title":"SSH Auth: __**accepted**__"'* ]]
    [[ "$output" == *'"description":"`SSH connection accepted`"'* ]]
    [[ "$output" == *'"value":"testuser"'* ]]
    [[ "$output" == *'"value":"`192.168.1.1`"'* ]]
    [[ "$output" == *'"value":"22"'* ]]
    [[ "$output" == *'"content":"@here"'* ]]
}

@test "generates JSON for failed status" {
    input='{"status":"failed","user":"baduser","ip":"10.0.0.1","port":"2222","logLine":"SSH connection failed"}'
    run bash -c "echo '$input' | $SCRIPT" 
    [ "$status" -eq 0 ]
    [[ "$output" == *'"title":"SSH Auth: __**failed**__"'* ]]
    [[ "$output" == *'"description":"`SSH connection failed`"'* ]]
    [[ "$output" == *'"value":"baduser"'* ]]
    [[ "$output" == *'"value":"`10.0.0.1`"'* ]]
    [[ "$output" == *'"value":"2222"'* ]]
    [[ "$output" == *'"content":""'* ]]
}

@test "uses correct colors for accepted vs failed" {
    # Test accepted (alert color)
    input='{"status":"accepted","user":"testuser","ip":"192.168.1.1","port":"22","logLine":"test"}'
    run bash -c "echo '$input' | $SCRIPT" 
    [[ "$output" == *'"color":16711680'* ]]
    
    # Test failed (ok color)
    input='{"status":"failed","user":"testuser","ip":"192.168.1.1","port":"22","logLine":"test"}'
    run bash -c "echo '$input' | $SCRIPT" 
    [[ "$output" == *'"color":65520'* ]]
}

@test "handles special characters in log line" {
    input='{"status":"accepted","user":"test user","ip":"192.168.1.1","port":"22","logLine":"Log with \"quotes\" and $pecial chars"}'
    run bash -c "echo '$input' | $SCRIPT" 
    [ "$status" -eq 0 ]
    [[ "$output" == *'Log with \"quotes\" and $pecial chars'* ]]
}
