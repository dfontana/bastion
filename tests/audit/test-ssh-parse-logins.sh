#!/usr/bin/env bats

setup() {
    export SCRIPT="${BATS_TEST_DIRNAME}/../../audit/ssh-parse-logins.sh"
}

@test "processes accepted passkey" {
    log_line="Jan 12 10:30:45 bastion sshd[12345]: Accepted publickey for testuser from 192.168.1.100 port 54321 ssh2"
    
    run bash -c "echo '$log_line' | $SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == '{"status":"accepted","user":"testuser","ip":"192.168.1.100","port":"54321","logLine":"Jan 12 10:30:45 bastion sshd[12345]: Accepted publickey for testuser from 192.168.1.100 port 54321 ssh2"}' ]]
}

@test "processes accepted password" {
    log_line="Jan 12 10:43:20 bastion sshd[1001]: Accepted password for admin from 172.16.0.1 port 55555 ssh2"
    
    run bash -c "echo '$log_line' | $SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == '{"status":"accepted","user":"admin","ip":"172.16.0.1","port":"55555","logLine":"Jan 12 10:43:20 bastion sshd[1001]: Accepted password for admin from 172.16.0.1 port 55555 ssh2"}' ]]
}

@test "processes failed password" {
    log_line="Jan 12 10:31:15 bastion sshd[12346]: Failed password for testuser from 10.0.0.50 port 12345 ssh2"
    
    run bash -c "echo '$log_line' | $SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == '{"status":"failed","user":"testuser","ip":"10.0.0.50","port":"12345","logLine":"Jan 12 10:31:15 bastion sshd[12346]: Failed password for testuser from 10.0.0.50 port 12345 ssh2"}' ]]
}

@test "processes invalid user attempts" {
    log_line="Jan 12 10:32:00 bastion sshd[12347]: Failed password for invalid user badguy from 172.16.0.10 port 22222 ssh2"
    
    run bash -c "echo '$log_line' | $SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == '{"status":"failed","user":"badguy","ip":"172.16.0.10","port":"22222","logLine":"Jan 12 10:32:00 bastion sshd[12347]: Failed password for invalid user badguy from 172.16.0.10 port 22222 ssh2"}' ]]
}

@test "processes authentication failures" {
    log_line="Jan 12 10:33:30 bastion sshd[12348]: authentication failure; logname= uid=0 euid=0 tty=ssh ruser= rhost=203.0.113.5 user=root"
    
    run bash -c "echo '$log_line' | $SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == '{"status":"failed","user":"root","ip":"203.0.113.5","port":"0","logLine":"Jan 12 10:33:30 bastion sshd[12348]: authentication failure; logname= uid=0 euid=0 tty=ssh ruser= rhost=203.0.113.5 user=root"}' ]]
}

@test "handles sshd auth lines with different formats" {
    log_lines="Jan 12 10:43:00 host sshd[999]: authentication failure for root from 203.0.113.1"    
    run bash -c "echo '$log_lines' | $SCRIPT"
    [ "$status" -eq 0 ]
    # Should process only the first matching log line
    [[ "$output" == '{"status":"failed","user":"root","ip":"203.0.113.1","port":"0","logLine":"Jan 12 10:43:00 host sshd[999]: authentication failure for root from 203.0.113.1"}' ]]
}

@test "ignores SSH lines without auth events" {
    log_line="Jan 12 10:34:30 bastion sshd[12349]: Server listening on 0.0.0.0 port 22"
    
    run bash -c "echo '$log_line' | $SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "handles missing user field gracefully" {
    log_line="Jan 12 10:35:00 bastion sshd[12350]: Accepted publickey from 192.168.1.200 port 33333 ssh2"
    
    run bash -c "echo '$log_line' | $SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == '{"status":"accepted","user":"unknown","ip":"192.168.1.200","port":"33333","logLine":"Jan 12 10:35:00 bastion sshd[12350]: Accepted publickey from 192.168.1.200 port 33333 ssh2"}' ]]
}

@test "handles missing IP field gracefully" {
    log_line="Jan 12 10:36:00 bastion sshd[12351]: Accepted publickey for testuser port 44444 ssh2"
    
    run bash -c "echo '$log_line' | $SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == '{"status":"accepted","user":"testuser","ip":"unknown","port":"44444","logLine":"Jan 12 10:36:00 bastion sshd[12351]: Accepted publickey for testuser port 44444 ssh2"}' ]]
}

@test "handles missing port field gracefully" {
    log_line="Jan 12 10:37:00 bastion sshd[12352]: Accepted publickey for testuser from 192.168.1.300 ssh2"
    
    run bash -c "echo '$log_line' | $SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == '{"status":"accepted","user":"testuser","ip":"192.168.1.300","port":"0","logLine":"Jan 12 10:37:00 bastion sshd[12352]: Accepted publickey for testuser from 192.168.1.300 ssh2"}' ]]
}

@test "extracts complex invalid user patterns" {
    log_line="Jan 12 10:39:00 bastion sshd[12355]: Invalid user admin123 from 203.0.113.100 port 55555"
    
    run bash -c "echo '$log_line' | $SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == '{"status":"failed","user":"admin123","ip":"203.0.113.100","port":"55555","logLine":"Jan 12 10:39:00 bastion sshd[12355]: Invalid user admin123 from 203.0.113.100 port 55555"}' ]]
}
