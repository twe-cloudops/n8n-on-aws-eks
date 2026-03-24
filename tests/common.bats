#!/usr/bin/env bats
# Tests for common.sh functions

setup() {
    # Source the common functions
    source "${BATS_TEST_DIRNAME}/../scripts/common.sh"
}

@test "check_command returns 0 for existing command" {
    run check_command "bash"
    [ "$status" -eq 0 ]
}

@test "check_command returns 1 for non-existing command" {
    run check_command "nonexistent-command-12345"
    [ "$status" -eq 1 ]
}

@test "log_info outputs message" {
    run log_info "test message"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "test message" ]]
}

@test "log_success outputs message" {
    run log_success "success message"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "success message" ]]
}

@test "log_warning outputs message" {
    run log_warning "warning message"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "warning message" ]]
}

@test "log_error outputs message to stderr" {
    run log_error "error message"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "error message" ]]
}

@test "check_prerequisites succeeds with valid commands" {
    run check_prerequisites bash echo
    [ "$status" -eq 0 ]
}

@test "check_prerequisites fails with invalid command" {
    run check_prerequisites bash nonexistent-command-12345
    [ "$status" -eq 1 ]
}

@test "ensure_backup_dir creates directory" {
    TEMP_DIR=$(mktemp -d)
    BACKUP_DIR="${TEMP_DIR}/test-backups"
    
    run ensure_backup_dir "$BACKUP_DIR"
    [ "$status" -eq 0 ]
    [ -d "$BACKUP_DIR" ]
    
    rm -rf "$TEMP_DIR"
}

@test "print_separator outputs line" {
    run print_separator
    [ "$status" -eq 0 ]
    [[ "$output" =~ "─" ]]
}

@test "print_header outputs formatted header" {
    run print_header "Test Header"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Test Header" ]]
}
