#!/usr/bin/env bats

setup() {
    export DEBUG=1
    export WEBHOOK_URL="https://discord.com/api/webhooks/test"
    export NOTIFY_CMD="tests/notify_mock.sh"
}

@test "ssh-log-watcher processes SSH accepted connections" {
    log_line="Jan 12 10:30:45 bastion sshd[12345]: Accepted publickey for testuser from 192.168.1.100 port 54321 ssh2"
    
    run bash -c "echo '$log_line' | ./ssh-log-watcher.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"notify.sh called with: -s accepted -u testuser -i 192.168.1.100 -p 54321 -l"* ]]
}

@test "ssh-log-watcher processes SSH failed password attempts" {
    log_line="Jan 12 10:31:15 bastion sshd[12346]: Failed password for testuser from 10.0.0.50 port 12345 ssh2"
    
    run bash -c "echo '$log_line' | ./ssh-log-watcher.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"notify.sh called with: -s failed -u testuser -i 10.0.0.50 -p 12345 -l"* ]]
}

@test "ssh-log-watcher processes invalid user attempts" {
    log_line="Jan 12 10:32:00 bastion sshd[12347]: Failed password for invalid user badguy from 172.16.0.10 port 22222 ssh2"
    
    run bash -c "echo '$log_line' | ./ssh-log-watcher.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"notify.sh called with: -s failed -u badguy -i 172.16.0.10 -p 22222 -l"* ]]
}

@test "ssh-log-watcher processes authentication failures" {
    log_line="Jan 12 10:33:30 bastion sshd[12348]: authentication failure; logname= uid=0 euid=0 tty=ssh ruser= rhost=203.0.113.5 user=root"
    
    run bash -c "echo '$log_line' | ./ssh-log-watcher.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"notify.sh called with: -s failed"* ]]
    [[ "$output" == *"-i 203.0.113.5"* ]]
}

@test "ssh-log-watcher ignores non-SSH log lines" {
    log_line="Jan 12 10:34:00 bastion systemd[1]: Started some service"
    
    run bash -c "echo '$log_line' | ./ssh-log-watcher.sh"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "ssh-log-watcher ignores SSH lines without auth events" {
    log_line="Jan 12 10:34:30 bastion sshd[12349]: Server listening on 0.0.0.0 port 22"
    
    run bash -c "echo '$log_line' | ./ssh-log-watcher.sh"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "ssh-log-watcher handles missing user field gracefully" {
    log_line="Jan 12 10:35:00 bastion sshd[12350]: Accepted publickey from 192.168.1.200 port 33333 ssh2"
    
    run bash -c "echo '$log_line' | ./ssh-log-watcher.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"-u unknown"* ]]
    [[ "$output" == *"-i 192.168.1.200"* ]]
    [[ "$output" == *"-p 33333"* ]]
}

@test "ssh-log-watcher handles missing IP field gracefully" {
    log_line="Jan 12 10:36:00 bastion sshd[12351]: Accepted publickey for testuser port 44444 ssh2"
    
    run bash -c "echo '$log_line' | ./ssh-log-watcher.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"-u testuser"* ]]
    [[ "$output" == *"-i unknown"* ]]
    [[ "$output" == *"-p 44444"* ]]
}

@test "ssh-log-watcher handles missing port field gracefully" {
    log_line="Jan 12 10:37:00 bastion sshd[12352]: Accepted publickey for testuser from 192.168.1.300 ssh2"
    
    run bash -c "echo '$log_line' | ./ssh-log-watcher.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"-u testuser"* ]]
    [[ "$output" == *"-i 192.168.1.300"* ]]
    [[ "$output" == *"-p 0"* ]]
}

@test "ssh-log-watcher processes multiple log lines" {
    log_lines="Jan 12 10:38:00 bastion sshd[12353]: Accepted publickey for user1 from 192.168.1.1 port 11111 ssh2
Jan 12 10:38:30 bastion sshd[12354]: Failed password for user2 from 192.168.1.2 port 22222 ssh2"
    
    run bash -c "echo '$log_lines' | ./ssh-log-watcher.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"-s accepted -u user1 -i 192.168.1.1 -p 11111"* ]]
    [[ "$output" == *"-s failed -u user2 -i 192.168.1.2 -p 22222"* ]]
}

@test "ssh-log-watcher extracts complex invalid user patterns" {
    log_line="Jan 12 10:39:00 bastion sshd[12355]: Invalid user admin123 from 203.0.113.100 port 55555"
    
    run bash -c "echo '$log_line' | ./ssh-log-watcher.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"-s failed -u admin123 -i 203.0.113.100 -p 55555"* ]]
}

# Additional tests for filtering behavior
@test "ssh-log-watcher filters out non-sshd log lines" {
    log_lines="Jan 12 10:40:00 bastion kernel: message
Jan 12 10:40:10 bastion systemd[1]: Service started
Jan 12 10:40:20 bastion cron[1234]: Job completed"
    
    run bash -c "echo '$log_lines' | ./ssh-log-watcher.sh"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "ssh-log-watcher filters out sshd lines without auth keywords" {
    log_lines="Jan 12 10:41:00 bastion sshd[12356]: Server listening on :: port 22
Jan 12 10:41:10 bastion sshd[12357]: Received SIGHUP; restarting
Jan 12 10:41:20 bastion sshd[12358]: Connection from 192.168.1.1 port 12345"
    
    run bash -c "echo '$log_lines' | ./ssh-log-watcher.sh"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "ssh-log-watcher processes mixed log lines correctly" {
    log_lines="Jan 12 10:42:00 bastion kernel: Random message
Jan 12 10:42:10 bastion sshd[12359]: Accepted publickey for testuser from 192.168.1.50 port 33333 ssh2
Jan 12 10:42:20 bastion systemd[1]: Another message
Jan 12 10:42:30 bastion sshd[12360]: Failed password for baduser from 10.0.0.1 port 22222 ssh2"
    
    run bash -c "echo '$log_lines' | ./ssh-log-watcher.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"-s accepted -u testuser -i 192.168.1.50 -p 33333"* ]]
    [[ "$output" == *"-s failed -u baduser -i 10.0.0.1 -p 22222"* ]]
    # Should not contain any mentions of kernel or systemd
    [[ "$output" != *"kernel"* ]]
    [[ "$output" != *"systemd"* ]]
}

@test "ssh-log-watcher handles sshd auth lines with different formats" {
    log_lines="Jan 12 10:43:00 host sshd[999]: authentication failure for root from 203.0.113.1
Jan 12 10:43:10 server sshd[1000]: Invalid user hacker from 198.51.100.1 port 44444
Jan 12 10:43:20 bastion sshd[1001]: Accepted password for admin from 172.16.0.1 port 55555 ssh2"
    
    run bash -c "echo '$log_lines' | ./ssh-log-watcher.sh"
    [ "$status" -eq 0 ]
    # All three should be processed as failed/accepted
    [[ "$output" == *"-s failed"*"root"*"203.0.113.1"* ]]
    [[ "$output" == *"-s failed"*"hacker"*"198.51.100.1"* ]]
    [[ "$output" == *"-s accepted"*"admin"*"172.16.0.1"* ]]
}

@test "ssh-log-watcher ignores case variations in sshd filtering" {
    log_lines="Jan 12 10:44:00 bastion SSHD[1002]: Accepted publickey for user1 from 192.168.1.100 port 11111 ssh2
Jan 12 10:44:10 bastion Sshd[1003]: Failed password for user2 from 192.168.1.200 port 22222 ssh2"
    
    # These should be ignored because case doesn't match our filter pattern
    run bash -c "echo '$log_lines' | ./ssh-log-watcher.sh"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}