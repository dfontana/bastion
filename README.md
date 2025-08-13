# Dotfiles for an SSH Bastion Host

## First Time Setup
(TODO: make install script)
- Ensure dependencies are installed: jq,rg,curl
- Copy each file to their intended location
- Restart SSHD after updating the sshd_config:
    ```
    rc-service sshd restart
    ```
- Enable the RC service and then verify it starts correctly:
    ```
    rc-update add ssh-log-watcher default
    rc-service ssh-log-watcher start
    ```
- Run the test suite to make sure log matching is functional on the given platform (TODO: Swap in a tool that is platform agnostic?)
    

## Testing

Tests are written using [BATS (Bash Automated Testing System)](https://github.com/bats-core/bats-core).

### Setup

Install BATS:
```bash
# macOS
brew install bats-core

# Ubuntu/Debian
sudo apt install bats

# Or install manually
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

### Running Tests

```bash
# Run all tests
bats tests/

# Run specific test file
bats tests/test_notify.sh
```

### Example Test

```bash
#!/usr/bin/env bats

@test "notify.sh validates required arguments" {
  run ./notify.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing"* ]]
}
```
