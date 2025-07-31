#!/bin/bash

# Local Helm Chart Testing Script
# This script helps you test your Helm chart locally before pushing to CI/CD

set -e

CHART_DIR="charts/wongnai-xds"
RELEASE_NAME="test-wongnai-xds"
NAMESPACE="default"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to check if helm is installed
check_helm() {
    if ! command -v helm &> /dev/null; then
        error "Helm is not installed. Please install Helm first."
        exit 1
    fi
    log "Helm version: $(helm version --short)"
}

# Function to check if helm unittest plugin is installed
check_unittest_plugin() {
    if ! helm plugin list | grep -q unittest; then
        warn "Helm unittest plugin not found. Installing..."
        helm plugin install https://github.com/helm-unittest/helm-unittest.git
    fi
    success "Helm unittest plugin is available"
}

# Function to lint the chart
lint_chart() {
    log "Linting Helm chart..."
    if helm lint "$CHART_DIR"; then
        success "Chart linting passed"
    else
        error "Chart linting failed"
        exit 1
    fi
}

# Function to run unit tests
run_unit_tests() {
    log "Running Helm unit tests..."
    if helm unittest "$CHART_DIR"; then
        success "Unit tests passed"
    else
        error "Unit tests failed"
        exit 1
    fi
}

# Function to test template rendering
test_template_rendering() {
    log "Testing template rendering with different values..."

    local values_files=("ci/test-values.yaml" "ci/minimal-values.yaml" "ci/production-values.yaml")

    for values_file in "${values_files[@]}"; do
        if [[ -f "$CHART_DIR/$values_file" ]]; then
            log "Testing with $values_file"
            helm template "$RELEASE_NAME" "$CHART_DIR" \
                --values "$CHART_DIR/$values_file" \
                --debug > /tmp/manifests-$(basename "$values_file" .yaml).yaml
            success "Template rendering with $values_file succeeded"
        else
            warn "Values file $values_file not found, skipping"
        fi
    done
}

# Function to validate generated manifests
validate_manifests() {
    log "Validating generated Kubernetes manifests..."

    # Check if kubeval is available
    if command -v kubeval &> /dev/null; then
        helm template "$RELEASE_NAME" "$CHART_DIR" | kubeval
        success "Manifest validation passed"
    else
        warn "kubeval not found. Install it for manifest validation: https://github.com/instrumenta/kubeval"
    fi
}

# Function to run dry-run install
dry_run_install() {
    log "Running dry-run installation..."
    if helm install "$RELEASE_NAME" "$CHART_DIR" --dry-run --debug; then
        success "Dry-run installation succeeded"
    else
        error "Dry-run installation failed"
        exit 1
    fi
}

# Function to install chart locally (requires kubectl context)
install_chart() {
    if [[ "$1" == "--install" ]]; then
        log "Installing chart locally..."

        # Check if kubectl is available and cluster is accessible
        if ! kubectl cluster-info &> /dev/null; then
            error "kubectl is not available or no cluster context is set"
            exit 1
        fi

        # Install the chart
        helm install "$RELEASE_NAME" "$CHART_DIR" \
            --values "$CHART_DIR/ci/test-values.yaml" \
            --wait \
            --timeout=5m

        success "Chart installed successfully"

        # Run helm tests
        log "Running Helm tests..."
        helm test "$RELEASE_NAME"

        # Show status
        kubectl get pods -l "app.kubernetes.io/instance=$RELEASE_NAME"
    fi
}

# Function to cleanup
cleanup() {
    if [[ "$1" == "--cleanup" ]]; then
        log "Cleaning up..."
        helm uninstall "$RELEASE_NAME" 2>/dev/null || true
        success "Cleanup completed"
    fi
}

# Main execution
main() {
    log "Starting Helm chart testing..."

    check_helm
    check_unittest_plugin
    lint_chart
    run_unit_tests
    test_template_rendering
    validate_manifests
    dry_run_install

    # Optional installation and cleanup
    install_chart "$@"
    cleanup "$@"

    success "All tests completed successfully!"
}

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Test Helm chart locally with comprehensive checks.

Options:
    --install    Install the chart to local cluster and run integration tests
    --cleanup    Cleanup installed chart (use with --install)
    --help       Show this help message

Examples:
    $0                           # Run all tests except installation
    $0 --install                 # Run all tests including installation
    $0 --install --cleanup       # Run all tests, install, then cleanup

Prerequisites:
    - helm (required)
    - kubectl (for --install option)
    - kubeval (optional, for manifest validation)
EOF
}

# Parse command line arguments
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    show_help
    exit 0
fi

main "$@"
