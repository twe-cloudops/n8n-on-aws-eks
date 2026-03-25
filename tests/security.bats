#!/usr/bin/env bats
# Security validation tests

@test "no hardcoded passwords in manifests" {
    # Check for literal passwords (secret references are OK)
    run grep -r "password: \"[a-zA-Z0-9]" "${BATS_TEST_DIRNAME}/../manifests/" || true
    # Should not find literal passwords
    [ -z "$output" ]
}

@test "owner secret has no hardcoded password" {
    run grep "password: \"\"" "${BATS_TEST_DIRNAME}/../manifests/01-n8n-owner-secret.yaml"
    [ "$status" -eq 0 ]
}

@test "n8n deployment has security context" {
    run grep "securityContext" "${BATS_TEST_DIRNAME}/../manifests/06-n8n-deployment-rds.yaml"
    [ "$status" -eq 0 ]
}

@test "n8n runs as non-root" {
    run grep "runAsNonRoot: true" "${BATS_TEST_DIRNAME}/../manifests/06-n8n-deployment-rds.yaml"
    [ "$status" -eq 0 ]
}

@test "capabilities are dropped in n8n" {
    run grep -A 2 "capabilities:" "${BATS_TEST_DIRNAME}/../manifests/06-n8n-deployment-rds.yaml"
    [[ "$output" =~ "drop" ]] && [[ "$output" =~ "ALL" ]]
}

@test "namespace has PSS labels" {
    run grep "pod-security.kubernetes.io/enforce" "${BATS_TEST_DIRNAME}/../manifests/00-namespace.yaml"
    [ "$status" -eq 0 ]
}

@test "no privileged containers" {
    run grep "privileged: true" "${BATS_TEST_DIRNAME}/../manifests/"
    [ "$status" -eq 1 ]
}

@test "scripts use strict mode" {
    for script in "${BATS_TEST_DIRNAME}/../scripts/"*.sh; do
        run grep "set -euo pipefail" "$script"
        [ "$status" -eq 0 ]
    done
}

@test "RDS SSL is enabled" {
    run grep "DB_POSTGRESDB_SSL_ENABLED" "${BATS_TEST_DIRNAME}/../manifests/06-n8n-deployment-rds.yaml"
    [ "$status" -eq 0 ]
}
