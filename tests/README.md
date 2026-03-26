# Testing Guide

This directory contains automated tests for the n8n-on-aws-eks project.

## Test Framework

We use [bats-core](https://github.com/bats-core/bats-core) for bash script testing.

## Installation

### macOS
```bash
brew install bats-core
```

### Linux
```bash
# Ubuntu/Debian
sudo apt-get install bats

# Or install from source
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

### Verify Installation
```bash
bats --version
```

## Running Tests

### Run All Tests
```bash
bats tests/
```

### Run Specific Test File
```bash
bats tests/common.bats
bats tests/manifests.bats
bats tests/scripts.bats
bats tests/security.bats
```

### Run Single Test
```bash
bats tests/common.bats -f "check_command returns 0"
```

### Verbose Output
```bash
bats tests/ --verbose
```

## Test Files

- **common.bats** - Tests for common.sh utility functions
- **manifests.bats** - Kubernetes manifest validation tests
- **scripts.bats** - Deployment script validation tests
- **security.bats** - Security compliance tests

## Prerequisites for Tests

Some tests require:
- `kubectl` installed
- Bash 4.0+
- Standard Unix utilities (grep, sed, etc.)

## CI/CD Integration

Tests can be run in GitHub Actions:

```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install bats
        run: |
          sudo apt-get update
          sudo apt-get install -y bats
      - name: Install kubectl
        run: |
          curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
          chmod +x kubectl
          sudo mv kubectl /usr/local/bin/
      - name: Run tests
        run: bats tests/
```

## Writing New Tests

### Test Structure
```bash
#!/usr/bin/env bats

setup() {
    # Run before each test
}

teardown() {
    # Run after each test
}

@test "description of test" {
    run command_to_test
    [ "$status" -eq 0 ]
    [[ "$output" =~ "expected output" ]]
}
```

### Assertions
```bash
[ "$status" -eq 0 ]           # Command succeeded
[ "$status" -ne 0 ]           # Command failed
[[ "$output" =~ "pattern" ]]  # Output matches pattern
[ -f "file" ]                 # File exists
[ -d "dir" ]                  # Directory exists
[ -x "script" ]               # File is executable
```

## Test Coverage

Current coverage:
- ✅ Common functions (12 tests)
- ✅ Kubernetes manifests (12 tests)
- ✅ Deployment scripts (14 tests)
- ✅ Security validation (7 tests)

**Total**: 45 tests

## Contributing

When adding new features:
1. Write tests first (TDD)
2. Ensure all tests pass
3. Add tests to appropriate file
4. Update this README if needed

## Troubleshooting

### Tests fail with "command not found"
Install missing prerequisites (kubectl, etc.)

### Permission denied errors
Make scripts executable: `chmod +x scripts/*.sh`

### YAML validation fails
Ensure kubectl is installed and configured
