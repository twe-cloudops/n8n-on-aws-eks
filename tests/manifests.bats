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

@test "postgres deployment is valid YAML" {
    run kubectl apply --dry-run=client -f "${BATS_TEST_DIRNAME}/../manifests/03-postgres-deployment.yaml"
    [ "$status" -eq 0 ]
}

@test "postgres deployment has security context" {
    run grep "securityContext" "${BATS_TEST_DIRNAME}/../manifests/03-postgres-deployment.yaml"
    [ "$status" -eq 0 ]
}

@test "postgres runs as non-root" {
    run grep "runAsNonRoot: true" "${BATS_TEST_DIRNAME}/../manifests/03-postgres-deployment.yaml"
    [ "$status" -eq 0 ]
}

@test "n8n deployment is valid YAML" {
    run kubectl apply --dry-run=client -f "${BATS_TEST_DIRNAME}/../manifests/06-n8n-deployment.yaml"
    [ "$status" -eq 0 ]
}

@test "n8n deployment has security context" {
    run grep "securityContext" "${BATS_TEST_DIRNAME}/../manifests/06-n8n-deployment.yaml"
    [ "$status" -eq 0 ]
}

@test "n8n runs as non-root" {
    run grep "runAsNonRoot: true" "${BATS_TEST_DIRNAME}/../manifests/06-n8n-deployment.yaml"
    [ "$status" -eq 0 ]
}

@test "service manifest is valid YAML" {
    run kubectl apply --dry-run=client -f "${BATS_TEST_DIRNAME}/../manifests/07-n8n-service.yaml"
    [ "$status" -eq 0 ]
}

@test "HPA manifest is valid YAML" {
    run kubectl apply --dry-run=client -f "${BATS_TEST_DIRNAME}/../manifests/08-hpa.yaml"
    [ "$status" -eq 0 ]
}

@test "external secrets manifests are valid YAML" {
    run kubectl apply --dry-run=client -f "${BATS_TEST_DIRNAME}/../manifests/secrets/"
    [ "$status" -eq 0 ]
}

@test "TLS manifests are valid YAML" {
    run kubectl apply --dry-run=client -f "${BATS_TEST_DIRNAME}/../manifests/tls/"
    [ "$status" -eq 0 ]
}
