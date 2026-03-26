#!/usr/bin/env bats
# Tests for Kubernetes manifests validation

@test "namespace manifest is valid YAML" {
    run kubectl apply --dry-run=client -f "${BATS_TEST_DIRNAME}/../manifests/00-namespace.yaml"
    [ "$status" -eq 0 ]
}

@test "namespace has Pod Security Standards labels" {
    run grep "pod-security.kubernetes.io/enforce" "${BATS_TEST_DIRNAME}/../manifests/00-namespace.yaml"
    [ "$status" -eq 0 ]
}

@test "n8n RDS deployment is valid YAML" {
    run kubectl apply --dry-run=client -f "${BATS_TEST_DIRNAME}/../manifests/06-n8n-deployment-rds.yaml"
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

@test "n8n deployment uses correct label" {
    run grep "app: n8n" "${BATS_TEST_DIRNAME}/../manifests/06-n8n-deployment-rds.yaml"
    [ "$status" -eq 0 ]
}

@test "service manifest is valid YAML" {
    run kubectl apply --dry-run=client -f "${BATS_TEST_DIRNAME}/../manifests/07-n8n-service.yaml"
    [ "$status" -eq 0 ]
}

@test "service uses correct name" {
    run grep "name: n8n-service" "${BATS_TEST_DIRNAME}/../manifests/07-n8n-service.yaml"
    [ "$status" -eq 0 ]
}

@test "service selector matches deployment" {
    run grep "app: n8n" "${BATS_TEST_DIRNAME}/../manifests/07-n8n-service.yaml"
    [ "$status" -eq 0 ]
}

@test "HPA manifest is valid YAML" {
    run kubectl apply --dry-run=client -f "${BATS_TEST_DIRNAME}/../manifests/08-hpa.yaml"
    [ "$status" -eq 0 ]
}

@test "HPA targets correct deployment" {
    run grep "name: n8n" "${BATS_TEST_DIRNAME}/../manifests/08-hpa.yaml"
    [ "$status" -eq 0 ]
}

@test "network policy is valid YAML" {
    run kubectl apply --dry-run=client -f "${BATS_TEST_DIRNAME}/../manifests/05-network-policy.yaml"
    [ "$status" -eq 0 ]
}

@test "persistent volumes manifest is valid YAML" {
    run kubectl apply --dry-run=client -f "${BATS_TEST_DIRNAME}/../manifests/02-persistent-volumes.yaml"
    [ "$status" -eq 0 ]
}
