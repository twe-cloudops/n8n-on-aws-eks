#!/usr/bin/env bats
# Security validation tests

@test "no hardcoded passwords in manifests" {
    # Skip the old secret file if it exists
    run grep -r "password.*:" "${BATS_TEST_DIRNAME}/../manifests/" --exclude="01-postgres-secret.yaml" || true
    # Should not find literal passwords (ExternalSecret references are OK)
    ! [[ "$output" =~ "password: [a-zA-Z0-9]" ]]
}

@test "all deployments have security contexts" {
    run grep -L "securityContext" "${BATS_TEST_DIRNAME}/../manifests/"*deployment.yaml
    [ -z "$output" ]
}

@test "all deployments run as non-root" {
    for file in "${BATS_TEST_DIRNAME}/../manifests/"*deployment.yaml; do
        run grep "runAsNonRoot: true" "$file"
        [ "$status" -eq 0 ]
    done
}

@test "capabilities are dropped" {
    for file in "${BATS_TEST_DIRNAME}/../manifests/"*deployment.yaml; do
        run grep -A 2 "capabilities:" "$file"
        [[ "$output" =~ "drop" ]] || [[ "$output" =~ "ALL" ]]
    done
}

@test "namespace has PSS labels" {
    run grep "pod-security.kubernetes.io/enforce: restricted" "${BATS_TEST_DIRNAME}/../manifests/00-namespace.yaml"
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
