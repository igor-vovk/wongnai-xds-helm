# Helm Chart Testing Guide

This guide explains how to test the wongnai-xds Helm chart using multiple testing strategies.

## Testing Layers

### 1. **Unit Tests** (using helm unittest)
- Tests individual template rendering
- Validates correct values are applied
- Tests conditional logic in templates

### 2. **Integration Tests** (using Helm test hooks)
- Tests actual service connectivity
- Validates HTTP and gRPC endpoints
- Runs inside Kubernetes cluster

### 3. **End-to-End Tests** (in GitHub Actions)
- Full deployment in kind cluster
- Real Kubernetes environment testing
- Security scanning with Checkov

### 4. **Local Testing** (using test-chart.sh)
- Development workflow testing
- Quick validation before commits

## Quick Start

### Local Testing (Recommended for Development)

```bash
# Run all tests locally (no cluster required)
./test-chart.sh

# Run tests and install to local cluster
./test-chart.sh --install

# Run tests, install, then cleanup
./test-chart.sh --install --cleanup

# Show help
./test-chart.sh --help
```

### Manual Testing Commands

```bash
# 1. Lint the chart
helm lint charts/wongnai-xds

# 2. Install helm unittest plugin (one-time setup)
helm plugin install https://github.com/helm-unittest/helm-unittest.git

# 3. Run unit tests
helm unittest charts/wongnai-xds

# 4. Test template rendering
helm template test-release charts/wongnai-xds --values charts/wongnai-xds/ci/test-values.yaml

# 5. Install and test in cluster
helm install test-release charts/wongnai-xds --values charts/wongnai-xds/ci/test-values.yaml
helm test test-release

# 6. Cleanup
helm uninstall test-release
```

## CI/CD Testing (GitHub Actions)

The `.github/workflows/test.yaml` workflow automatically runs on:
- Push to main/master branches
- Pull requests

### Workflow Jobs:

1. **lint-and-validate**: Lints chart, validates manifests, runs unit tests
2. **security-scan**: Scans generated manifests for security issues
3. **end-to-end-test**: Creates kind cluster, installs chart, runs integration tests
4. **test-different-values**: Tests with multiple values files

## Test Files Structure

```
charts/wongnai-xds/
├── tests/                          # Unit tests (helm unittest)
│   ├── deployment_test.yaml
│   ├── service_test.yaml
│   ├── configmap_test.yaml
│   └── serviceaccount_test.yaml
├── templates/tests/                # Integration tests (helm test)
│   └── test-connection.yaml
├── ci/                            # Test values files
│   ├── test-values.yaml          # Standard test configuration
│   ├── minimal-values.yaml       # Minimal resource configuration
│   └── production-values.yaml    # Production-like configuration
```

## What Each Test Does

### Unit Tests (`charts/wongnai-xds/tests/`)
- **deployment_test.yaml**: Tests deployment template with various configurations
- **service_test.yaml**: Validates service ports and selectors
- **configmap_test.yaml**: Tests ConfigMap creation conditions
- **serviceaccount_test.yaml**: Tests ServiceAccount creation and configuration

### Integration Tests (`charts/wongnai-xds/templates/tests/`)
- **test-connection.yaml**: Tests HTTP and gRPC endpoint connectivity

### Values Files (`charts/wongnai-xds/ci/`)
- **test-values.yaml**: Standard test configuration with moderate resources
- **minimal-values.yaml**: Minimal configuration for basic functionality
- **production-values.yaml**: Production-like configuration with security settings

## Prerequisites

### For Local Testing:
- **helm** (required) - Install from https://helm.sh/docs/intro/install/
- **kubectl** (for --install option) - For cluster integration tests
- **kubeval** (optional) - For manifest validation: https://github.com/instrumenta/kubeval

### For CI/CD:
All dependencies are automatically installed in GitHub Actions workflow.

## Adding New Tests

### Adding Unit Tests:
1. Create new test file in `charts/wongnai-xds/tests/`
2. Follow the helm unittest syntax
3. Test both positive and negative scenarios

### Adding Integration Tests:
1. Add new test pod in `charts/wongnai-xds/templates/tests/`
2. Use `helm.sh/hook: test` annotation
3. Test actual functionality, not just connectivity

### Adding Values Files:
1. Create new values file in `charts/wongnai-xds/ci/`
2. Add to the matrix in `.github/workflows/test.yaml`
3. Test edge cases and different configurations

## Troubleshooting

### Common Issues:

1. **Helm unittest plugin not found**:
   ```bash
   helm plugin install https://github.com/helm-unittest/helm-unittest.git
   ```

2. **kubectl context not set** (for local installation):
   ```bash
   kubectl config current-context
   kubectl config use-context your-context
   ```

3. **Test failures in CI**:
   - Check the GitHub Actions logs
   - Run the same test locally with `./test-chart.sh`
   - Verify your changes with `helm template` first

### Debug Tips:

```bash
# Debug template rendering
helm template test-release charts/wongnai-xds --debug

# Check what tests would run
helm unittest charts/wongnai-xds --dry-run

# Test specific values file
helm template test-release charts/wongnai-xds \
  --values charts/wongnai-xds/ci/test-values.yaml \
  --debug
```

## Best Practices

1. **Always run tests locally** before pushing
2. **Add tests for new features** - both unit and integration
3. **Test with different values files** to ensure flexibility
4. **Keep tests fast** - avoid unnecessary wait times
5. **Use meaningful test names** and descriptions
6. **Test failure scenarios** not just success paths

## Security Testing

The CI pipeline includes security scanning with Checkov that checks for:
- Container security best practices
- Kubernetes security policies
- Resource limits and security contexts
- Network policies and service configurations

Fix security issues by updating your templates or values files accordingly.
