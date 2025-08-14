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
- Run the test suite to make sure log matching is functional on the given platform
    

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
bats test/**/*.sh
```

### Example Test

```bash
#!/usr/bin/env bats

@test "validates required arguments" {
  run ./my-script.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing"* ]]
}
```
