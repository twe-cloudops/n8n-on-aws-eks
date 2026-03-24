#!/usr/bin/env bats
# Tests for deployment script validation

@test "deploy.sh exists and is executable" {
    [ -x "${BATS_TEST_DIRNAME}/../scripts/deploy.sh" ]
}

@test "deploy.sh has help option" {
    run "${BATS_TEST_DIRNAME}/../scripts/deploy.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage" ]]
}

@test "deploy.sh sources common.sh" {
    run grep "source.*common.sh" "${BATS_TEST_DIRNAME}/../scripts/deploy.sh"
    [ "$status" -eq 0 ]
}

@test "deploy.sh has error handling" {
    run grep "set -euo pipefail" "${BATS_TEST_DIRNAME}/../scripts/deploy.sh"
    [ "$status" -eq 0 ]
}

@test "deploy.sh validates prerequisites" {
    run grep "check_prerequisites" "${BATS_TEST_DIRNAME}/../scripts/deploy.sh"
    [ "$status" -eq 0 ]
}

@test "deploy.sh supports VPC configuration" {
    run grep "VPC_ID" "${BATS_TEST_DIRNAME}/../scripts/deploy.sh"
    [ "$status" -eq 0 ]
}

@test "deploy.sh supports Secrets Manager" {
    run grep "ENABLE_SECRETS_MANAGER" "${BATS_TEST_DIRNAME}/../scripts/deploy.sh"
    [ "$status" -eq 0 ]
}

@test "deploy.sh supports ACM" {
    run grep "USE_ACM" "${BATS_TEST_DIRNAME}/../scripts/deploy.sh"
    [ "$status" -eq 0 ]
}

@test "cleanup.sh exists and is executable" {
    [ -x "${BATS_TEST_DIRNAME}/../scripts/cleanup.sh" ]
}

@test "cleanup.sh has help option" {
    run "${BATS_TEST_DIRNAME}/../scripts/cleanup.sh" --help
    [ "$status" -eq 0 ]
}

@test "backup.sh exists and is executable" {
    [ -x "${BATS_TEST_DIRNAME}/../scripts/backup.sh" ]
}

@test "restore.sh exists and is executable" {
    [ -x "${BATS_TEST_DIRNAME}/../scripts/restore.sh" ]
}

@test "monitor.sh exists and is executable" {
    [ -x "${BATS_TEST_DIRNAME}/../scripts/monitor.sh" ]
}

@test "get-logs.sh exists and is executable" {
    [ -x "${BATS_TEST_DIRNAME}/../scripts/get-logs.sh" ]
}
