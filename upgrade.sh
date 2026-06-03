#!/bin/bash
#
# Copyright (c) 2023-2025 Bito Inc.
# All rights reserved.
#
# This source code is proprietary and confidential to Bito Inc.
# Unauthorized copying, modification, distribution, or use is strictly prohibited.
#
# For licensing information, see the COPYRIGHT file in the root directory.
#
# @company Bito Inc.
# @website https://bito.ai
#
# Bito AI Architect Blue/Green Upgrade Script
# Standalone script - no external dependencies required

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OLD_DIR=""
CUSTOM_OLD_PATH=""
PARENT_DIR=""
TEMP_DOWNLOAD_DIR="/tmp/bito-upgrade-$$"
TARGET_VERSION=""
CUSTOM_URL=""
DOWNLOAD_BASE_URL="${UPGRADE_DOWNLOAD_URL:-https://aiarch.bito.ai}"
LOG_FILE="/tmp/bito-upgrade-$$.log"

# Global variables
NEW_DIR=""
NEW_ENV=""
OLD_ENV=""
UPGRADE_MODE=""  # Will be set to "embedded", "standalone", or "kubernetes"
CURRENT_VERSION=""
DOCKER_COMPOSE_CMD=""
DEPLOYMENT_TYPE="docker-compose"  # Will be set to "kubernetes" if detected

# Print functions
msg_success() { echo -e "${GREEN}✓${NC} $1" | tee -a "$LOG_FILE"; }
msg_error() { echo -e "${RED}✗${NC} $1" | tee -a "$LOG_FILE"; }
msg_info() { echo -e "${BLUE}ℹ${NC} $1" | tee -a "$LOG_FILE"; }
msg_warn() { echo -e "${YELLOW}⚠${NC} $1" | tee -a "$LOG_FILE"; }

# Safe single-step progress spinner. Inlined (not sourced from
# scripts/lib/progress-output.sh) so upgrade.sh stays a standalone script with
# no external deps. Backgrounds the WORK, animates the spinner in the
# FOREGROUND, polls the child with `kill -0` (signal 0 = existence check; sends
# NO signal), and waits for natural exit. Never calls `kill <pid>` — avoids the
# documented macOS SIGTERM-on-parent race (exit 143). Honors BITOARCH_NO_SPINNER
# / non-TTY with a static line. Wrapped command's output is routed to LOG_FILE.
# Usage: run_with_spinner "<label>" <cmd> [args...]
run_with_spinner() {
    local label="$1"; shift
    local start=$SECONDS rc=0

    if [ ! -t 1 ] || [ "${BITOARCH_NO_SPINNER:-}" = "1" ]; then
        printf '[+] %s ... ' "$label"
        ( "$@" >> "$LOG_FILE" 2>&1 ) || rc=$?
    else
        ( "$@" >> "$LOG_FILE" 2>&1 ) &
        local child=$! spinner='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' i=0
        while kill -0 "$child" 2>/dev/null; do
            printf '\r[+] %s %s' "$label" "${spinner:$i:1}"
            i=$(( (i + 1) % ${#spinner} ))
            sleep 0.1
        done
        wait "$child" 2>/dev/null || rc=$?
        printf '\r\033[K[+] %s ... ' "$label"
    fi

    if [ "$rc" -eq 0 ]; then
        printf '%b✓%b done (%ds)\n' "${GREEN:-}" "${NC:-}" "$((SECONDS - start))"
    else
        printf '%b✗%b failed (%ds)\n' "${RED:-}" "${NC:-}" "$((SECONDS - start))" >&2
    fi
    return $rc
}

print_header() {
    echo "" | tee -a "$LOG_FILE"
    echo -e "${BLUE}${BOLD:-}$1${NC}" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
}

log_silent() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Detect docker compose command
detect_docker_compose() {
    if docker compose version >/dev/null 2>&1; then
        echo "docker compose"
    elif docker-compose --version >/dev/null 2>&1; then
        echo "docker-compose"
    else
        return 1
    fi
}

# Detect current installation version
detect_current_version() {
    local install_dir="$1"
    local versions_file="${install_dir}/versions/service-versions.json"
    
    if [[ -f "$versions_file" ]]; then
        # Try with jq first
        if command -v jq >/dev/null 2>&1; then
            CURRENT_VERSION=$(jq -r '.platform_info.version // "unknown"' "$versions_file" 2>/dev/null || echo "unknown")
        else
            # Fallback to grep/cut
            CURRENT_VERSION=$(grep -m1 '"version":' "$versions_file" 2>/dev/null | cut -d'"' -f4 || echo "unknown")
        fi
        
        log_silent "Detected current version: $CURRENT_VERSION"
        return 0
    else
        CURRENT_VERSION="unknown"
        log_silent "No versions file found, version unknown"
        return 1
    fi
}

# Show usage
#
# User-facing help advertises ONLY customer-relevant options. The following
# flags are intentionally undocumented here -- they still work, but they're
# for developer / testing / air-gapped-install scenarios, not customers:
#   --url=<tarball>    Upgrade from a custom tarball URL (air-gapped / testing)
#   --old-path=<dir>   Override auto-detected old install dir (testing)
#   --source=<path>    Use a custom upgrade.sh (testing unreleased versions;
#                      intercepted by bitoarch upgrade case, never forwarded)
show_usage() {
    cat << EOF
Bito AI Architect Upgrade

Usage: bitoarch upgrade [--version=VERSION]

Auto-detects the installed version and upgrades to the latest release,
preserving data (MySQL, volumes, configs).

Options:
  --version=VERSION    Upgrade to a specific version (default: latest)
  --help               Show this help message

Examples:
  # Upgrade to latest:
  bitoarch upgrade

  # Upgrade to a specific version:
  bitoarch upgrade --version=2.0.0

Features:
  • Zero downtime (blue/green deployment)
  • Data preservation (MySQL, volumes, configs)
  • Automatic version detection

EOF
}

# Detect deployment type
detect_deployment_type() {
    # Check multiple locations for .deployment-type file
    # For 1.4.x+: file is in /usr/local or ~/.local (standard paths)
    # For older versions (1.3.x): file is in OLD_DIR
    local deployment_type_file=""
    
    if [[ -f "${OLD_DIR}/.deployment-type" ]] && [[ ! -L "${OLD_DIR}/.deployment-type" ]]; then
        deployment_type_file="${OLD_DIR}/.deployment-type"
    elif [[ -f "/usr/local/etc/bitoarch/.deployment-type" ]]; then
        deployment_type_file="/usr/local/etc/bitoarch/.deployment-type"
    elif [[ -f "${HOME}/.local/bitoarch/etc/.deployment-type" ]]; then
        deployment_type_file="${HOME}/.local/bitoarch/etc/.deployment-type"
    fi

    if [[ -n "$deployment_type_file" ]]; then
        DEPLOYMENT_TYPE=$(cat "$deployment_type_file")
    else
        DEPLOYMENT_TYPE="docker-compose"
    fi
    msg_info "Deployment type: $DEPLOYMENT_TYPE"
    log_silent "Deployment type: ${DEPLOYMENT_TYPE} (source: ${deployment_type_file:-default})"
}

# A directory is a valid install if it carries the install structure
# (scripts/bitoarch.sh) AND the customer's .env-bitoarch is reachable — in
# the dir itself (1.3.x layout) or the standard config dir (1.4.x+). The
# .env-bitoarch is NOT required to live in the install dir, which is why the
# old "must have OLD_DIR/.env-bitoarch" check wrongly rejected fresh
# Docker/K8s installs (their env lives only in /usr/local/etc/bitoarch).
_validate_install_dir() {
    local dir="$1"
    [ -n "$dir" ] && [ -d "$dir" ] || return 1
    # Dev-clone guard: a dir with .git/ is a source checkout, not a deployed
    # install. Mirrors uninstall.sh's safety check — prevents treating a clone
    # as OLD_DIR (which would, e.g., surface "rm -rf <clone>" in the
    # post-upgrade cleanup hint).
    [ -d "${dir}/.git" ] && return 1
    [ -f "${dir}/scripts/bitoarch.sh" ] || return 1
    [ -f "${dir}/.env-bitoarch" ] && return 0
    [ -f "/usr/local/etc/bitoarch/.env-bitoarch" ] && return 0
    [ -f "${HOME}/.local/bitoarch/etc/.env-bitoarch" ] && return 0
    return 1
}

# Resolve the customer's active .env-bitoarch: install-dir copy for 1.3.x,
# standard config dir for 1.4.x+.
_resolve_old_env() {
    if [ -f "${OLD_DIR}/.env-bitoarch" ]; then
        echo "${OLD_DIR}/.env-bitoarch"
    elif [ -f "/usr/local/etc/bitoarch/.env-bitoarch" ]; then
        echo "/usr/local/etc/bitoarch/.env-bitoarch"
    elif [ -f "${HOME}/.local/bitoarch/etc/.env-bitoarch" ]; then
        echo "${HOME}/.local/bitoarch/etc/.env-bitoarch"
    else
        echo "${OLD_DIR}/.env-bitoarch"
    fi
}

# Resolve the install dir to upgrade, in priority order:
#   1. --old-path (explicit override)
#   2. Script location — when run as the bundled <install>/scripts/upgrade.sh,
#      the install dir is the script's parent. Reliable for every edition
#      (standalone, Enterprise, K8s) regardless of CLI-symlink layout, which is
#      how upgrades are normally invoked. Dev checkouts are filtered out by
#      _validate_install_dir's .git guard.
#   3. bitoarch CLI symlink (user- or system-layout) — for runs from outside
#      the install tree; resolves whatever install the live CLI points at.
#   4. Prompt (last resort).
# Every candidate is confirmed by _validate_install_dir, which accepts an install
# whose .env-bitoarch lives in the standard config dir (the Enterprise/K8s case).
_resolve_old_dir() {
    local candidate target cli

    if [[ -n "$CUSTOM_OLD_PATH" ]]; then
        OLD_DIR="${CUSTOM_OLD_PATH/#\~/$HOME}"
        msg_info "Using provided installation path: $OLD_DIR"
        if ! _validate_install_dir "$OLD_DIR"; then
            msg_error "Not a valid installation directory: $OLD_DIR"
            exit 1
        fi
        return 0
    fi

    # Bundled-script case: <install>/scripts/upgrade.sh -> install dir is SCRIPT_DIR's parent.
    candidate="$(dirname "$SCRIPT_DIR")"
    if _validate_install_dir "$candidate"; then
        OLD_DIR="$candidate"
        msg_info "Detected installation: $OLD_DIR"
        return 0
    fi

    # CLI symlink (user- or system-layout) -> <install>/scripts/bitoarch.sh.
    for cli in "${HOME}/.local/bin/bitoarch" "/usr/local/bin/bitoarch"; do
        [ -L "$cli" ] || continue
        target="$(readlink "$cli")"
        candidate="$(cd "$(dirname "$target")/.." 2>/dev/null && pwd)"
        if _validate_install_dir "$candidate"; then
            OLD_DIR="$candidate"
            msg_info "Detected installation: $OLD_DIR"
            return 0
        fi
    done

    echo ""
    msg_warn "Could not auto-detect the existing installation"
    msg_info "Provide the path to your existing installation"
    echo ""
    read -p "Enter path to existing installation: " OLD_DIR
    OLD_DIR="${OLD_DIR/#\~/$HOME}"
    if ! _validate_install_dir "$OLD_DIR"; then
        msg_error "Not a valid installation directory"
        exit 1
    fi
}

# Parse arguments
parse_args() {
    TARGET_VERSION="latest"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --old-path=*)
                CUSTOM_OLD_PATH="${1#--old-path=}"
                shift
                ;;
            --version=*)
                TARGET_VERSION="${1#--version=}"
                shift
                ;;
            --url=*)
                CUSTOM_URL="${1#--url=}"
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                msg_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Determine OLD_DIR via the resolver cascade (--old-path → CLI symlink →
    # prompt). Validates against standard config dir so fresh Docker/K8s
    # installs (env only in /usr/local/etc/bitoarch) are accepted.
    _resolve_old_dir

    PARENT_DIR="$(dirname "$OLD_DIR")"
    OLD_ENV="$(_resolve_old_env)"
    
    # Detect deployment type first
    detect_deployment_type
    
    # Detect current version and determine upgrade mode
    detect_current_version "$OLD_DIR"
    
    msg_info "Current version: $CURRENT_VERSION"

    if [[ "$DEPLOYMENT_TYPE" == "kubernetes" ]]; then
        UPGRADE_MODE="kubernetes"
    elif [[ "$CURRENT_VERSION" == "1.0.0" ]]; then
        UPGRADE_MODE="standalone"
    else
        UPGRADE_MODE="embedded"
        [[ "$CURRENT_VERSION" == "unknown" ]] && msg_warn "Could not detect current version; using default upgrade flow"
    fi

    log_silent "Upgrade mode: $UPGRADE_MODE (deployment: $DEPLOYMENT_TYPE, version: $CURRENT_VERSION)"
    
    if [[ -n "$CUSTOM_URL" ]] && [[ "$TARGET_VERSION" != "latest" ]]; then
        msg_error "Cannot use both --url and --version"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    msg_info "Checking system requirements..."
    
    local missing=()
    for tool in curl tar jq; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing+=("$tool")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        msg_error "Missing required tools: ${missing[*]}"
        msg_info "Install them:"
        msg_info "  macOS: brew install ${missing[*]}"
        msg_info "  Ubuntu: apt-get install ${missing[*]}"
        exit 1
    fi
    
    # Kubernetes-specific prerequisites
    if [[ "$UPGRADE_MODE" == "kubernetes" ]]; then
        msg_info "Checking Kubernetes prerequisites..."
        
        # Check kubectl
        if ! command -v kubectl >/dev/null 2>&1; then
            msg_error "kubectl not found (required for Kubernetes deployment)"
            msg_info "Install kubectl:"
            msg_info "  macOS: brew install kubectl"
            msg_info "  Ubuntu: sudo apt-get install -y kubectl"
            exit 1
        fi
        
        # Check helm
        if ! command -v helm >/dev/null 2>&1; then
            msg_error "Helm not found (required for Kubernetes deployment)"
            msg_info "Install Helm:"
            msg_info "  macOS: brew install helm"
            msg_info "  Ubuntu: curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
            exit 1
        fi
        
        # Check kubectl connectivity
        if ! kubectl cluster-info >/dev/null 2>&1; then
            msg_error "Cannot connect to Kubernetes cluster"
            msg_info "Please ensure kubectl is configured correctly"
            exit 1
        fi
        
        log_silent "Kubernetes prerequisites verified: kubectl and helm found"
        msg_success "Kubernetes prerequisites verified"
    else
        # Docker prerequisites for non-K8s deployments
        if ! docker info >/dev/null 2>&1; then
            msg_error "Docker is not running"
            exit 1
        fi
        
        # Detect docker compose command for ALL non-k8s modes (embedded +
        # standalone use it). Previously gated on standalone only, which made
        # embedded silently fall through to `docker compose` even on hosts
        # that only have docker-compose v1 installed.
        DOCKER_COMPOSE_CMD=$(detect_docker_compose)
        if [[ -z "$DOCKER_COMPOSE_CMD" ]]; then
            msg_error "Docker Compose not found (tried 'docker compose' and 'docker-compose')"
            exit 1
        fi
        log_silent "Using docker compose command: $DOCKER_COMPOSE_CMD"
    fi
    
    msg_success "System requirements verified"
}

# Verify old installation
verify_old_installation() {
    msg_info "Verifying existing installation..."
    
    if [[ ! -d "$OLD_DIR" ]]; then
        msg_error "Old installation not found: $OLD_DIR"
        exit 1
    fi
    
    # Check for config files in multiple locations
    # For 1.4.x+: files might be in /usr/local or ~/.local (standard paths)
    # For older versions (1.3.x): files are in OLD_DIR
    local config_found=false
    if [[ -f "${OLD_DIR}/.env-bitoarch" ]] && [[ ! -L "${OLD_DIR}/.env-bitoarch" ]]; then
        # Regular file in OLD_DIR (1.3.x or older)
        config_found=true
        log_silent "Config found in OLD_DIR (regular file)"
    elif [[ -f "/usr/local/etc/bitoarch/.env-bitoarch" ]]; then
        config_found=true
        log_silent "Config found in /usr/local/etc/bitoarch"
    elif [[ -f "${HOME}/.local/bitoarch/etc/.env-bitoarch" ]]; then
        config_found=true
        log_silent "Config found in ~/.local/bitoarch/etc"
    elif [[ -L "${OLD_DIR}/.env-bitoarch" ]]; then
        # Symlink in OLD_DIR - follow it to check actual file
        if [[ -f "${OLD_DIR}/.env-bitoarch" ]]; then
            config_found=true
            log_silent "Config found via symlink in OLD_DIR"
        fi
    fi
    
    if [[ "$config_found" == "false" ]]; then
        msg_error "Configuration not found"
        exit 1
    fi
    
    if [[ ! -f "${OLD_DIR}/setup.sh" ]]; then
        msg_error "setup.sh not found in: $OLD_DIR"
        exit 1
    fi
    
    msg_success "Existing installation verified"
}

# Check if indexing is running and prompt user before proceeding.
# Delegates to the OLD installation's manager-adapter
# API version that install exposes (v2 today, v3 later) and get docker/k8s
# handling for free via ensure_manager_service_accessible.
check_indexing_not_running() {
    msg_info "Checking indexing status..."

    local old_bitoarch="${OLD_DIR}/scripts/bitoarch.sh"
    if [[ ! -f "$old_bitoarch" ]]; then
        log_silent "Old bitoarch.sh not found at $old_bitoarch — skipping indexing check"
        msg_warn "Old bitoarch.sh not found — skipping indexing check"
        return 0
    fi

    if ! command -v jq >/dev/null 2>&1; then
        log_silent "jq not available — skipping indexing check"
        msg_warn "jq not installed — skipping indexing check"
        return 0
    fi

    # Invoke the OLD install's bitoarch index-status directly — it handles
    # env loading, docker/k8s detection, port-forward setup
    # API version (v2/v3) that install exposes. Runs as a subprocess so its
    # env/init does not leak into upgrade.sh.
    # Temporarily disable set -e so a non-zero exit (service unreachable,
    # port-forward failure, etc.) falls through to skip-with-warning instead
    # of aborting the upgrade.
    local status_json rc
    set +e
    status_json=$(bash "$old_bitoarch" index-status --output json 2>/dev/null)
    rc=$?
    set -e

    if [[ $rc -ne 0 || -z "$status_json" ]]; then
        log_silent "manager_status failed (rc=$rc) — skipping indexing check"
        msg_warn "Manager status unavailable — skipping indexing check"
        return 0
    fi

    local repo_status cross_repo_status
    repo_status=$(echo "$status_json" | jq -r '.status // "unknown"' 2>/dev/null)
    cross_repo_status=$(echo "$status_json" | jq -r '.workspace_level_index.ws_status // "unknown"' 2>/dev/null)
    log_silent "Indexing status — repo: $repo_status, cross-repo: $cross_repo_status"

    if [[ ( -z "$repo_status" || "$repo_status" == "unknown" ) \
        && ( -z "$cross_repo_status" || "$cross_repo_status" == "unknown" ) ]]; then
        log_silent "Indexing status unparseable (body: $status_json)"
        msg_warn "Indexing status unparseable — skipping indexing check"
        return 0
    fi

    # Active set per IndexStatus enum
    local is_active="false"
    for s in "$repo_status" "$cross_repo_status"; do
        if [[ "$s" == "running" || "$s" == "pausing" \
              || "$s" == "stopping" || "$s" == "resuming" ]]; then
            is_active="true"
        fi
    done

    if [[ "$is_active" == "true" ]]; then
        echo ""
        msg_warn "Indexing is currently active"
        echo ""
        read -p "$(echo -e "${YELLOW}Do you want to proceed with the upgrade? (y/N): ${NC}")" user_choice
        case "$user_choice" in
            [yY]|[yY][eE][sS])
                log_silent "User chose to proceed despite active indexing"
                msg_info "Proceeding with upgrade..."
                ;;
            *)
                log_silent "User chose to abort due to active indexing"
                msg_error "Upgrade aborted. Please wait for indexing to complete and try again."
                exit 0
                ;;
        esac
    else
        msg_success "Indexing check passed"
    fi
}

# Download package
download_package() {
    local version="$1"
    local download_url="$2"
    
    msg_info "Downloading version ${version}..." >&2
    log_silent "Download URL: $download_url"

    mkdir -p "$TEMP_DOWNLOAD_DIR"
    local tarball_name=$(basename "$download_url")
    local tarball_path="${TEMP_DOWNLOAD_DIR}/${tarball_name}"

    set +e
    curl -# -L -f -o "$tarball_path" "$download_url" >&2
    local curl_exit=$?
    set -e

    if [[ $curl_exit -ne 0 ]]; then
        msg_error "Download failed (curl exit: $curl_exit): $download_url" >&2
        msg_info "Check URL accessibility and internet connection" >&2
        rm -rf "$TEMP_DOWNLOAD_DIR"
        exit 1
    fi
    
    if [[ ! -f "$tarball_path" ]]; then
        msg_error "Downloaded file not created" >&2
        rm -rf "$TEMP_DOWNLOAD_DIR"
        exit 1
    fi
    
    if [[ ! -s "$tarball_path" ]]; then
        msg_error "Downloaded file is empty" >&2
        rm -rf "$TEMP_DOWNLOAD_DIR"
        exit 1
    fi
    
    local size_mb=$(du -m "$tarball_path" | cut -f1)
    msg_success "Package downloaded (${size_mb}MB)" >&2
    
    # Only output the path to stdout (everything else goes to stderr)
    echo "$tarball_path"
}

# Extract package
extract_package() {
    local tarball_path="$1"
    local version="$2"
    
    msg_info "Extracting package..."
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    NEW_DIR="${PARENT_DIR}/bito-ai-architect-${version}-${timestamp}"
    
    mkdir -p "$NEW_DIR"
    
    # Extract with strip-components=1 to remove the top-level directory from tarball
    if ! tar -xzf "$tarball_path" --strip-components=1 -C "$NEW_DIR" 2>&1 | tee -a "$LOG_FILE" >/dev/null; then
        msg_error "Extraction failed"
        rm -rf "$NEW_DIR"
        exit 1
    fi
    
    # Verify critical files exist
    if [[ ! -f "${NEW_DIR}/setup.sh" ]]; then
        msg_error "Invalid package (missing setup.sh)"
        rm -rf "$NEW_DIR"
        exit 1
    fi
    
    if [[ ! -f "${NEW_DIR}/bitoarch" ]]; then
        msg_error "Invalid package (missing bitoarch)"
        rm -rf "$NEW_DIR"
        exit 1
    fi
    
    if [[ ! -d "${NEW_DIR}/scripts/lib" ]]; then
        msg_error "Invalid package (missing scripts/lib directory)"
        rm -rf "$NEW_DIR"
        exit 1
    fi
    
    # Make scripts executable
    chmod +x "${NEW_DIR}/setup.sh"
    chmod +x "${NEW_DIR}/bitoarch"
    [[ -f "${NEW_DIR}/scripts/upgrade.sh" ]] && chmod +x "${NEW_DIR}/scripts/upgrade.sh"
    
    msg_success "Package extracted to: $NEW_DIR"
}

# Merge new config keys from default env file into existing env file
# This ensures new configuration options added in newer versions are available
# with their default values while preserving user's existing configuration
merge_new_env_configs() {
    local env_file="$1"
    local default_env_file="${NEW_DIR}/.env-bitoarch.default"
    
    if [[ ! -f "$default_env_file" ]]; then
        log_silent "Skipping env config merge - default file not found: $default_env_file"
        return 0
    fi
    
    if [[ ! -f "$env_file" ]]; then
        log_silent "Skipping env config merge - env file not found: $env_file"
        return 0
    fi

    local new_keys_added=0
    local temp_additions
    temp_additions=$(mktemp)

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)= ]]; then
            local key="${BASH_REMATCH[1]}"

            if ! grep -q "^${key}=" "$env_file" 2>/dev/null; then
                echo "$line" >> "$temp_additions"
                new_keys_added=$((new_keys_added + 1))
            fi
        fi
    done < "$default_env_file"

    if [[ $new_keys_added -gt 0 ]]; then
        echo "" >> "$env_file"
        echo "# ============================================================================" >> "$env_file"
        echo "# NEW CONFIGURATION OPTIONS (added during upgrade from version ${CURRENT_VERSION:-unknown})" >> "$env_file"
        echo "# Added on: $(date)" >> "$env_file"
        echo "# ============================================================================" >> "$env_file"
        cat "$temp_additions" >> "$env_file"

        log_silent "Merged $new_keys_added new config keys into env file"
    fi

    rm -f "$temp_additions"
    return 0
}

# Patch env file with IMAGE variables from new version
patch_env_with_images() {
    local env_file="$1"
    local versions_file="${NEW_DIR}/versions/service-versions.json"

    local images_exist=false
    grep -q "CIS_CONFIG_IMAGE=" "$env_file" 2>/dev/null && images_exist=true
    
    # Read versions and image bases from NEW version's versions/service-versions.json
    local cis_config_version cis_config_image_base
    local cis_manager_version cis_manager_image_base
    local cis_provider_version cis_provider_image_base
    local cis_tracker_version cis_tracker_image_base
    local mysql_version mysql_image_base
    local temporal_version temporal_image_base
    local cis_worker_version cis_worker_image_base

    if command -v jq >/dev/null 2>&1 && [[ -f "$versions_file" ]]; then
        cis_config_version=$(jq -r '.services."cis-config".version' "$versions_file" 2>/dev/null || echo "latest")
        cis_config_image_base=$(jq -r '.services."cis-config".image' "$versions_file" 2>/dev/null || echo "docker.io/bitoai/cis-config")
        
        cis_manager_version=$(jq -r '.services."cis-manager".version' "$versions_file" 2>/dev/null || echo "latest")
        cis_manager_image_base=$(jq -r '.services."cis-manager".image' "$versions_file" 2>/dev/null || echo "docker.io/bitoai/cis-manager")
        
        cis_provider_version=$(jq -r '.services."cis-provider".version' "$versions_file" 2>/dev/null || echo "latest")
        cis_provider_image_base=$(jq -r '.services."cis-provider".image' "$versions_file" 2>/dev/null || echo "docker.io/bitoai/xmcp")
        
        cis_tracker_version=$(jq -r '.services."cis-tracker".version' "$versions_file" 2>/dev/null || echo "latest")
        cis_tracker_image_base=$(jq -r '.services."cis-tracker".image' "$versions_file" 2>/dev/null || echo "docker.io/bitoai/cis-tracking")
        
        mysql_version=$(jq -r '.services."mysql".version' "$versions_file" 2>/dev/null || echo "8.0")
        mysql_image_base=$(jq -r '.services."mysql".image' "$versions_file" 2>/dev/null || echo "mysql")

        temporal_version=$(jq -r '.services."temporal".version' "$versions_file" 2>/dev/null || echo "1.24.2")
        temporal_image_base=$(jq -r '.services."temporal".image' "$versions_file" 2>/dev/null || echo "temporalio/auto-setup")

        cis_worker_version=$(jq -r '.services."cis-worker".version' "$versions_file" 2>/dev/null || echo "latest")
        cis_worker_image_base=$(jq -r '.services."cis-worker".image' "$versions_file" 2>/dev/null || echo "docker.io/bitoai/cis-worker")
    else
        # Fallback to defaults if jq not available or file missing
        cis_config_version="latest"
        cis_config_image_base="docker.io/bitoai/cis-config"
        cis_manager_version="latest"
        cis_manager_image_base="docker.io/bitoai/cis-manager"
        cis_provider_version="latest"
        cis_provider_image_base="docker.io/bitoai/xmcp"
        cis_tracker_version="latest"
        cis_tracker_image_base="docker.io/bitoai/cis-tracking"
        mysql_version="8.0"
        mysql_image_base="mysql"
        temporal_version="1.24.2"
        temporal_image_base="temporalio/auto-setup"
        cis_worker_version="latest"
        cis_worker_image_base="docker.io/bitoai/cis-worker"
    fi
    
    # Add or update IMAGE variables
    if [ "$images_exist" = true ]; then
        # Update existing IMAGE variables
        sed -i.bak "s|^CIS_CONFIG_IMAGE=.*|CIS_CONFIG_IMAGE=${cis_config_image_base}:${cis_config_version}|" "$env_file"
        sed -i.bak "s|^CIS_MANAGER_IMAGE=.*|CIS_MANAGER_IMAGE=${cis_manager_image_base}:${cis_manager_version}|" "$env_file"
        sed -i.bak "s|^CIS_PROVIDER_IMAGE=.*|CIS_PROVIDER_IMAGE=${cis_provider_image_base}:${cis_provider_version}|" "$env_file"
        sed -i.bak "s|^CIS_TRACKER_IMAGE=.*|CIS_TRACKER_IMAGE=${cis_tracker_image_base}:${cis_tracker_version}|" "$env_file"
        sed -i.bak "s|^MYSQL_IMAGE=.*|MYSQL_IMAGE=${mysql_image_base}:${mysql_version}|" "$env_file"
        sed -i.bak "s|^TEMPORAL_IMAGE=.*|TEMPORAL_IMAGE=${temporal_image_base}:${temporal_version}|" "$env_file"
        sed -i.bak "s|^CIS_WORKER_IMAGE=.*|CIS_WORKER_IMAGE=${cis_worker_image_base}:${cis_worker_version}|" "$env_file"
        if ! grep -q "^TEMPORAL_IMAGE=" "$env_file"; then
            printf '\nTEMPORAL_IMAGE=%s:%s\n' "${temporal_image_base}" "${temporal_version}" >> "$env_file"
        fi
        if ! grep -q "^CIS_WORKER_IMAGE=" "$env_file"; then
            printf '\nCIS_WORKER_IMAGE=%s:%s\n' "${cis_worker_image_base}" "${cis_worker_version}" >> "$env_file"
        fi
    else
        # Append IMAGE variables to env file
        cat >> "$env_file" << EOF

# Image variables (added during upgrade for compatibility with new version)
CIS_CONFIG_IMAGE=${cis_config_image_base}:${cis_config_version}
CIS_MANAGER_IMAGE=${cis_manager_image_base}:${cis_manager_version}
CIS_PROVIDER_IMAGE=${cis_provider_image_base}:${cis_provider_version}
CIS_TRACKER_IMAGE=${cis_tracker_image_base}:${cis_tracker_version}
MYSQL_IMAGE=${mysql_image_base}:${mysql_version}
TEMPORAL_IMAGE=${temporal_image_base}:${temporal_version}
CIS_WORKER_IMAGE=${cis_worker_image_base}:${cis_worker_version}
EOF
    fi
    
    # Also update VERSION variables if they're empty
    if grep -q "^CIS_CONFIG_VERSION=$" "$env_file" 2>/dev/null; then
        sed -i.bak "s/^CIS_CONFIG_VERSION=$/CIS_CONFIG_VERSION=${cis_config_version}/" "$env_file"
    fi
    if grep -q "^CIS_MANAGER_VERSION=$" "$env_file" 2>/dev/null; then
        sed -i.bak "s/^CIS_MANAGER_VERSION=$/CIS_MANAGER_VERSION=${cis_manager_version}/" "$env_file"
    fi
    if grep -q "^CIS_PROVIDER_VERSION=$" "$env_file" 2>/dev/null; then
        sed -i.bak "s/^CIS_PROVIDER_VERSION=$/CIS_PROVIDER_VERSION=${cis_provider_version}/" "$env_file"
    fi
    if grep -q "^CIS_TRACKER_VERSION=$" "$env_file" 2>/dev/null; then
        sed -i.bak "s/^CIS_TRACKER_VERSION=$/CIS_TRACKER_VERSION=${cis_tracker_version}/" "$env_file"
    fi
    
    # Clean up sed backup files
    rm -f "${env_file}.bak"
    
    log_silent "Patched env with images: config=${cis_config_version}, manager=${cis_manager_version}, provider=${cis_provider_version}, tracker=${cis_tracker_version}, mysql=${mysql_version}, temporal=${temporal_version}, worker=${cis_worker_version}"
}

# Migrate configuration
migrate_config() {
    msg_info "Migrating configuration..."
    
    # Backup old .env-bitoarch before migration
    if [ -f "${OLD_DIR}/.env-bitoarch" ]; then
        # Determine standard backup directory
        local backup_var_dir
        if [[ -d "/usr/local/var/bitoarch" ]] || [[ -w "/usr/local/var" ]]; then
            backup_var_dir="/usr/local/var/bitoarch"
        else
            backup_var_dir="${HOME}/.local/bitoarch/var"
        fi
        
        local backup_dir="${backup_var_dir}/backups/configs/env"
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local backup_file="${backup_dir}/.env-bitoarch.backup.${timestamp}"
        
        # Create backup directory
        mkdir -p "$backup_dir" 2>/dev/null || {
            if command -v sudo >/dev/null 2>&1; then
                sudo mkdir -p "$backup_dir"
                sudo chown -R "$USER:$(id -gn)" "$backup_dir"
            fi
        }
        
        # Create backup
        if cp "${OLD_DIR}/.env-bitoarch" "$backup_file" 2>/dev/null; then
            log_silent "Config backup saved to: $backup_file"
            msg_info "Config backup: $backup_file"
        else
            msg_warn "Could not create config backup (non-critical)"
        fi
        
        # Rotate old backups (keep latest 5)
        local retention=5
        local backup_pattern="${backup_dir}/.env-bitoarch.backup.*"
        local existing_backups=$(ls -t $backup_pattern 2>/dev/null | wc -l | tr -d ' ')
        
        if [ "$existing_backups" -gt "$retention" ]; then
            ls -t $backup_pattern 2>/dev/null | tail -n +$((retention + 1)) | xargs rm -f 2>/dev/null || true
            log_silent "Rotated old backups (keeping latest ${retention})"
        fi
    fi
    
    NEW_ENV="${NEW_DIR}/.env-bitoarch"
    
    # Determine config source directory
    # For 1.4.x+: configs are in /usr/local or ~/.local (standard paths)
    # For older versions (1.3.x): configs are regular files in OLD_DIR
    local config_source="$OLD_DIR"
    
    if [[ -f "${OLD_DIR}/.env-bitoarch" ]] && [[ ! -L "${OLD_DIR}/.env-bitoarch" ]]; then
        config_source="$OLD_DIR"
    elif [[ -f "/usr/local/etc/bitoarch/.env-bitoarch" ]]; then
        config_source="/usr/local/etc/bitoarch"
    elif [[ -f "${HOME}/.local/bitoarch/etc/.env-bitoarch" ]]; then
        config_source="${HOME}/.local/bitoarch/etc"
    elif [[ -L "${OLD_DIR}/.env-bitoarch" ]] && [[ -f "${OLD_DIR}/.env-bitoarch" ]]; then
        config_source="$OLD_DIR"
    fi

    log_silent "Config source: $config_source"
    
    # Copy env files from detected source
    [[ -f "${config_source}/.env-bitoarch" ]] && cp "${config_source}/.env-bitoarch" "${NEW_DIR}/.env-bitoarch"
    [[ -f "${config_source}/.env-llm-bitoarch" ]] && cp "${config_source}/.env-llm-bitoarch" "${NEW_DIR}/.env-llm-bitoarch"

    # Copy repo config
    if [[ -f "${config_source}/.bitoarch-config.yaml" ]]; then
        cp "${config_source}/.bitoarch-config.yaml" "${NEW_DIR}/.bitoarch-config.yaml"
    fi

    # Carry the user's git-repo-list.yaml so the new install retains tracked
    # repos (otherwise the new install loses prior repo state).
    if [[ -f "${config_source}/.git-repo-list.yaml" ]]; then
        cp "${config_source}/.git-repo-list.yaml" "${NEW_DIR}/.git-repo-list.yaml"
    fi

    if [[ -f "${config_source}/.deployment-type" ]]; then
        cp "${config_source}/.deployment-type" "${NEW_DIR}/.deployment-type"
    else
        echo "docker-compose" > "${NEW_DIR}/.deployment-type"
    fi
    
    # Merge new config keys from default env file (adds missing keys with default values)
    if [[ -f "$NEW_ENV" ]]; then
        merge_new_env_configs "$NEW_ENV"
    fi

    # Migrate legacy unified lookback to per-feature keys (pre-1.8.4).
    if [[ -f "$NEW_ENV" ]] && grep -qE '^INSIGHTS_LOOKBACK_DAYS=' "$NEW_ENV"; then
        local _legacy_lb
        _legacy_lb=$(grep -E '^INSIGHTS_LOOKBACK_DAYS=' "$NEW_ENV" | cut -d= -f2- | tr -d '"' | tr -d "'")
        if [ -n "$_legacy_lb" ]; then
            grep -qE '^INSIGHTS_GIT_LOOKBACK_DAYS=.+' "$NEW_ENV" \
                || sed -i.bak "s|^INSIGHTS_GIT_LOOKBACK_DAYS=.*|INSIGHTS_GIT_LOOKBACK_DAYS=${_legacy_lb}|" "$NEW_ENV"
            grep -qE '^INSIGHTS_JIRA_LOOKBACK_DAYS=.+' "$NEW_ENV" \
                || sed -i.bak "s|^INSIGHTS_JIRA_LOOKBACK_DAYS=.*|INSIGHTS_JIRA_LOOKBACK_DAYS=${_legacy_lb}|" "$NEW_ENV"
        fi
        sed -i.bak '/^INSIGHTS_LOOKBACK_DAYS=/d' "$NEW_ENV"
        rm -f "${NEW_ENV}.bak"
        log_silent "Migrated INSIGHTS_LOOKBACK_DAYS to per-feature keys"
    fi

    # Replace TEMPORAL_MYSQL_PASSWORD placeholder with a real random secret.
    # The default template ships CHANGE_THIS_PASSWORD so every install would
    # otherwise end up with the same well-known password for temporal_user.
    if [[ -f "$NEW_ENV" ]] && grep -qE '^TEMPORAL_MYSQL_PASSWORD=(CHANGE_THIS_PASSWORD)?$' "$NEW_ENV"; then
        # Reuse generate_secret from the new package's setup-utils so upgrade and
        # fresh-install produce identical secret formats.
        local setup_utils="${NEW_DIR}/scripts/setup-utils.sh"
        local temporal_pass=""
        if [[ -f "$setup_utils" ]]; then
            # shellcheck disable=SC1090
            source "$setup_utils"
            temporal_pass=$(generate_secret)
        else
            temporal_pass=$( (openssl rand -base64 32 2>/dev/null || head -c 32 /dev/urandom | base64) | tr -d '\n' )
        fi
        sed -i.bak "s|^TEMPORAL_MYSQL_PASSWORD=.*|TEMPORAL_MYSQL_PASSWORD=${temporal_pass}|" "$NEW_ENV"
        rm -f "${NEW_ENV}.bak"
        log_silent "Generated new TEMPORAL_MYSQL_PASSWORD (replaced placeholder)"
    fi
    if [[ -f "$NEW_ENV" ]] && ! grep -q '^TEMPORAL_MYSQL_USER=' "$NEW_ENV"; then
        printf 'TEMPORAL_MYSQL_USER=temporal_user\n' >> "$NEW_ENV"
    fi

    # Patch env file with IMAGE variables if missing (for old versions)
    if [[ -f "$NEW_ENV" ]]; then
        patch_env_with_images "$NEW_ENV"
    fi

    # Extract latest provider default.json from new package image
    # This ensures the new version's config is used for both Docker and K8s
    local deployment_type="docker-compose"
    if [[ -f "${NEW_DIR}/.deployment-type" ]]; then
        deployment_type=$(cat "${NEW_DIR}/.deployment-type")
    fi

    if [[ "$deployment_type" == "docker-compose" ]]; then
        local docker_config_path="${NEW_DIR}/services/cis-provider/config/default.json"

        # Ensure destination directory exists; docker cp fails if parent is missing
        local docker_config_dir
        docker_config_dir="$(dirname "$docker_config_path")"
        if [[ ! -d "$docker_config_dir" ]]; then
            log_silent "[provider-config] dest dir missing, creating: $docker_config_dir"
            mkdir -p "$docker_config_dir" 2>> "$LOG_FILE" || \
                log_silent "[provider-config] mkdir -p failed for $docker_config_dir"
        fi

        # Source env to get provider image
        if [[ -f "$NEW_ENV" ]]; then
            source "$NEW_ENV"
            local provider_image="${CIS_PROVIDER_IMAGE:-}"

            if [[ -n "$provider_image" ]]; then
                # Pull the image first
                if docker pull "$provider_image" >> "$LOG_FILE" 2>&1; then
                    # Create temp container and extract config
                    if docker create --name temp-provider-config-upgrade "$provider_image" >/dev/null 2>&1; then
                        if docker cp temp-provider-config-upgrade:/opt/bito/xmcp/config/default.json "$docker_config_path" 2>> "$LOG_FILE"; then
                            chmod 666 "$docker_config_path" 2>/dev/null || true
                            log_silent "Provider configuration extracted from new image"
                        else
                            msg_warn "Could not extract provider config from image, using packaged config"
                        fi
                        docker rm temp-provider-config-upgrade >/dev/null 2>&1 || true
                    else
                        msg_warn "Could not create temp container for config extraction"
                    fi
                else
                    msg_warn "Could not pull provider image for config extraction"
                fi
            fi
        fi
    else
        local k8s_config_path="${NEW_DIR}/helm-bitoarch/services/cis-provider/config/default.json"

        if [[ -f "$NEW_ENV" ]]; then
            source "$NEW_ENV"
            local provider_image="${CIS_PROVIDER_IMAGE:-}"

            if [[ -n "$provider_image" ]]; then
                if docker pull "$provider_image" >> "$LOG_FILE" 2>&1; then
                    if docker create --name temp-provider-config-k8s-upgrade "$provider_image" >/dev/null 2>&1; then
                        if docker cp temp-provider-config-k8s-upgrade:/opt/bito/xmcp/config/default.json "$k8s_config_path" 2>> "$LOG_FILE"; then
                            chmod 666 "$k8s_config_path" 2>/dev/null || true
                            log_silent "Provider config extracted to: $k8s_config_path"
                        else
                            msg_warn "Could not extract provider config from image, using packaged config"
                        fi
                        docker rm temp-provider-config-k8s-upgrade >/dev/null 2>&1 || true
                    else
                        msg_warn "Could not create temp container for config extraction"
                    fi
                else
                    msg_warn "Could not pull provider image for config extraction"
                fi
            else
                msg_warn "Provider image not set in env, using packaged config"
            fi
        else
            msg_warn "Env file not found, using packaged config"
        fi
    fi

    msg_success "Configuration migrated"
}

# Check if docker volumes exist from old installation
check_old_volumes() {
    local volumes_found=0
    local found_project_name=""
    local all_volumes
    all_volumes=$(docker volume ls --format "{{.Name}}" 2>/dev/null)

    for suffix in "ai_architect_mysql_data" "ai_architect_data" "ai_architect_backups" "ai_architect_temp"; do
        local matching_vol
        matching_vol=$(echo "$all_volumes" | grep -E "_${suffix}$" | head -1)
        if [[ -n "$matching_vol" ]]; then
            volumes_found=$((volumes_found + 1))
            if [[ -z "$found_project_name" ]]; then
                found_project_name=$(echo "$matching_vol" | sed "s/_${suffix}$//")
            fi
        fi
    done

    if [[ $volumes_found -gt 0 ]]; then
        log_silent "Found $volumes_found data volume(s) from project: $found_project_name"
        msg_info "Data will be preserved during the upgrade..." >&2
        echo "$found_project_name"
    else
        msg_warn "No existing data volumes found - fresh volumes will be created" >&2
        echo ""
    fi
}

# Configure shared volumes
configure_volumes() {
    local compose_file="${NEW_DIR}/docker-compose.yml"
    local old_volumes_project
    old_volumes_project=$(check_old_volumes)

    cp "$compose_file" "${compose_file}.backup"

    awk '
        /^volumes:/ { in_volumes=1; next }
        in_volumes && /^[a-z]/ { in_volumes=0 }
        !in_volumes { print }
    ' "$compose_file" > "${compose_file}.tmp"

    if [[ -n "$old_volumes_project" ]]; then
        cat >> "${compose_file}.tmp" << EOF

volumes:
  ai_architect_mysql_data:
    external: true
    name: ${old_volumes_project}_ai_architect_mysql_data
  ai_architect_data:
    external: true
    name: ${old_volumes_project}_ai_architect_data
  ai_architect_backups:
    external: true
    name: ${old_volumes_project}_ai_architect_backups
  ai_architect_temp:
    external: true
    name: ${old_volumes_project}_ai_architect_temp
  ai_architect_insights:
EOF
        # ai_architect_insights only exists in installs from 1.8.4+, but
        # check_old_volumes keys off the four core volumes — so old_volumes_project
        # can be set while the insights volume does not exist (upgrade from an
        # older release). Declaring a missing volume external hard-fails
        # compose-up ("declared as external, but could not be found"), so mount
        # it external only when present, else local so compose creates a fresh one.
        if docker volume inspect "${old_volumes_project}_ai_architect_insights" >/dev/null 2>&1; then
            cat >> "${compose_file}.tmp" << EOF
    external: true
    name: ${old_volumes_project}_ai_architect_insights
EOF
            log_silent "Insights volume: reusing ${old_volumes_project}_ai_architect_insights"
        else
            cat >> "${compose_file}.tmp" << 'EOF'
    driver: local
EOF
            log_silent "Insights volume: fresh (no prior volume for old project)"
        fi
        log_silent "Volume config: external (from $old_volumes_project)"
    else
        cat >> "${compose_file}.tmp" << 'EOF'

volumes:
  ai_architect_mysql_data:
    driver: local
  ai_architect_data:
    driver: local
  ai_architect_backups:
    driver: local
  ai_architect_temp:
    driver: local
  ai_architect_insights:
    driver: local
EOF
        log_silent "Volume config: fresh local volumes"
    fi

    mv "${compose_file}.tmp" "$compose_file"
}

# Remove leftover ai-architect-* containers and network so the new compose-up
# doesn't collide on container_name. Idempotent. Output → setup.log.
_cleanup_previous_containers() {
    docker ps -a --filter "name=ai-architect" --format "{{.Names}}" \
        | xargs -r docker rm -f >> "$LOG_FILE" 2>&1 || true
    docker network ls --format "{{.Name}}" | grep -F "ai-architect-network" \
        | xargs -r docker network rm >> "$LOG_FILE" 2>&1 || true
}

# Run `docker compose up -d --pull always` against $env_file in the background,
# wait for completion, return compose's exit code. Handles v2 / v1 / pre-v1.25
# compose variants. Caller is responsible for cd "$NEW_DIR". Output appended
# to LOG_FILE so compose errors survive in setup.log.
_compose_up_new_version() {
    local env_file="$1"
    log_silent "compose up -d --pull always | env_file=$env_file | cwd=$(pwd) | compose_cmd=${DOCKER_COMPOSE_CMD:-docker compose}"

    if [[ "$DOCKER_COMPOSE_CMD" == "docker compose" ]] || [[ -z "$DOCKER_COMPOSE_CMD" ]]; then
        docker compose --env-file "$env_file" up -d --pull always >> "$LOG_FILE" 2>&1 &
    elif $DOCKER_COMPOSE_CMD --help | grep -q "\-\-env-file"; then
        $DOCKER_COMPOSE_CMD --env-file "$env_file" pull >> "$LOG_FILE" 2>&1 || true
        $DOCKER_COMPOSE_CMD --env-file "$env_file" up -d >> "$LOG_FILE" 2>&1 &
    else
        set -a; source "$env_file"; set +a
        $DOCKER_COMPOSE_CMD pull >> "$LOG_FILE" 2>&1 || true
        $DOCKER_COMPOSE_CMD up -d >> "$LOG_FILE" 2>&1 &
    fi
    local pid=$!
    while kill -0 $pid 2>/dev/null; do sleep 2; done
    set +e; wait $pid; local rc=$?; set -e
    [ "$rc" -ne 0 ] && log_silent "compose up failed (rc=$rc)"
    return $rc
}

# Bring new-install artifacts into place before the deploy step. Applies to
# all upgrade modes. Each step self-gates so Enterprise / non-HTTPS installs
# no-op the parts they don't need. Replaces the side effects that
# setup.sh --from-existing-config used to perform (CLI relink, MCP cert prep).
prepare_new_install_artifacts() {
    msg_info "Preparing new install artifacts..."

    # CLI symlink → new install. Was previously done inline by setup.sh
    # (embedded); consolidated here so all modes get the relink.
    local cli_target="${HOME}/.local/bin/bitoarch"
    local cli_source="${NEW_DIR}/scripts/bitoarch.sh"
    if [[ -f "$cli_source" ]]; then
        mkdir -p "$(dirname "$cli_target")"
        chmod +x "$cli_source"
        ln -sf "$cli_source" "$cli_target"
        log_silent "CLI symlink updated: $cli_target -> $cli_source"
    fi

    # MCP HTTPS cert provisioning — must run in upgrade.sh's shell (not a
    # subshell): the function exports HOST_MCP_CERT_DIR + XMCP_INTERNAL_PORT
    # which docker-compose.yml needs at compose-up time. Self-gates on
    # MCP_TRANSPORT=https so Enterprise / HTTP-only no-ops. path-manager.sh
    # sourced first because mcp-cert.sh depends on get_user_cache_dir.
    if [[ "$UPGRADE_MODE" != "kubernetes" ]] && [[ -f "${NEW_DIR}/scripts/lib/mcp-cert.sh" ]]; then
        local _mcp_t
        _mcp_t=$(grep -E '^MCP_TRANSPORT=' "${NEW_DIR}/.env-bitoarch" 2>/dev/null \
                 | head -1 | cut -d= -f2- | tr -d '"' | tr -d "'")
        export MCP_TRANSPORT="${_mcp_t:-http}"
        if [ -f "${NEW_DIR}/scripts/lib/path-manager.sh" ]; then
            # shellcheck disable=SC1091
            source "${NEW_DIR}/scripts/lib/path-manager.sh"
            command -v init_paths >/dev/null 2>&1 && init_paths >/dev/null 2>&1 || true
        fi
        # shellcheck disable=SC1091
        source "${NEW_DIR}/scripts/lib/mcp-cert.sh"
        if command -v mcp_cert_prepare_for_compose >/dev/null 2>&1; then
            mcp_cert_prepare_for_compose >> "$LOG_FILE" 2>&1 || true
        fi
    fi

    msg_success "Install artifacts prepared"
}

# Fire install_run's post-install hooks against the new install. Sources
# install.sh from NEW_DIR which transitively loads path-manager,
# bitoarch-config, all hook libs, and the shared apply/persist helpers.
# Re-exports install-mode flags from the customer's .env-bitoarch, applies
# Standalone defaults for any not yet present, fires the hooks, then
# persists the resulting flag set. Each hook self-gates on its own flag
# (auto_recovery_enabled, MCP_TRANSPORT, etc.), so Enterprise installs
# no-op the Standalone-only ones.
run_post_install_hooks() {
    log_silent "Running post-install hooks..."
    (
        export SCRIPT_DIR="${NEW_DIR}"
        export PLATFORM_DIR="${NEW_DIR}"

        # shellcheck disable=SC1091
        [ -f "${NEW_DIR}/scripts/lib/install.sh" ] && source "${NEW_DIR}/scripts/lib/install.sh"

        # Re-export install-mode flags from the customer's .env-bitoarch so
        # the standalone-defaults check + the hook predicates see them.
        local env_file flag v
        env_file=$(get_config_file 2>/dev/null)
        if [ -n "$env_file" ] && [ -f "$env_file" ]; then
            for flag in SKIP_SSO_PROMPT AUTO_GENERATE_MCP_TOKEN COMPACT_INSTALL_PROGRESS BITOARCH_AUTORECOVERY; do
                v=$(grep -E "^${flag}=" "$env_file" 2>/dev/null \
                    | head -1 | cut -d= -f2- | tr -d '"' | tr -d "'")
                [ -n "$v" ] && export "$flag=$v"
            done
        fi

        command -v _install_apply_standalone_defaults >/dev/null 2>&1 && \
            _install_apply_standalone_defaults

        command -v restart_policy_migrate >/dev/null 2>&1 && restart_policy_migrate >> "$LOG_FILE" 2>&1 || true
        command -v autostart_install     >/dev/null 2>&1 && autostart_install     >> "$LOG_FILE" 2>&1 || true
        command -v cert_cron_install     >/dev/null 2>&1 && cert_cron_install     >> "$LOG_FILE" 2>&1 || true

        command -v _install_persist_mode_flags >/dev/null 2>&1 && \
            _install_persist_mode_flags
    )
    log_silent "Post-install hooks completed"
}

# Start new version - EMBEDDED MODE (direct docker compose).
# Mirrors start_new_version_standalone's compose-up pattern. CLI relink,
# MCP cert prep, and SQL staging are handled by prepare_new_install_artifacts.
start_new_version() {
    log_silent "Starting new version..."

    cd "$NEW_DIR" || exit 1

    configure_volumes

    # Sync migrated configs to standard location so anything reading via
    # get_config_file() / get_config_dir() sees the carried-over values.
    # shellcheck disable=SC1090
    source "${NEW_DIR}/scripts/lib/path-manager.sh"
    init_paths

    local standard_config_dir="$(get_config_dir)"
    mkdir -p "$standard_config_dir"

    for config_file in .env-bitoarch .env-llm-bitoarch .bitoarch-config.yaml .git-repo-list.yaml .deployment-type; do
        if [[ -f "${NEW_DIR}/${config_file}" ]]; then
            cp "${NEW_DIR}/${config_file}" "$standard_config_dir/${config_file}"
        fi
    done

    log_silent "Configs synced to $standard_config_dir"

    _cleanup_previous_containers

    msg_info "Starting services (this may take 2-5 minutes)..."
    if ! run_with_spinner "AI Architect Deployment In Progress" \
            _deploy_and_wait_healthy "${standard_config_dir}/.env-bitoarch"; then
        msg_error "Failed to start new version"
        msg_info "Check log file: $LOG_FILE"
        exit 1
    fi
    log_silent "New version started"
}

# Start new version - STANDALONE MODE (direct docker compose)
start_new_version_standalone() {
    log_silent "Starting new version (standalone mode)..."

    cd "$NEW_DIR" || exit 1
    configure_volumes
    _cleanup_previous_containers

    msg_info "Starting services (this may take 2-5 minutes)..."
    if ! run_with_spinner "AI Architect Deployment In Progress" \
            _deploy_and_wait_healthy "$ENV_FILE"; then
        msg_error "Failed to start new version"
        msg_info "Check log file: $LOG_FILE"
        exit 1
    fi
    log_silent "New version started"
}

# Compose-up the new version, then poll bitoarch health until all services are
# healthy (or UPGRADE_HEALTH_WAIT_SECS elapses). One unit so run_with_spinner
# can wrap the whole deploy+settle as a single backgrounded command. Polling
# actual health (not a fixed sleep) is what keeps post-install hooks
# (autostart/cert-cron via launchd RunAtLoad) from firing before cis-manager
# finishes its first-boot Wingman download. Returns non-zero only if compose-up
# fails; a health-wait timeout still returns 0 (post-install hooks self-gate,
# so a slow-but-up stack shouldn't abort the upgrade).
_deploy_and_wait_healthy() {
    local env_file="$1"
    _compose_up_new_version "$env_file" || return 1

    local elapsed=0 budget="${UPGRADE_HEALTH_WAIT_SECS:-360}"
    local cli="${HOME}/.local/bin/bitoarch"
    while [ "$elapsed" -lt "$budget" ]; do
        if "$cli" health >/dev/null 2>&1; then
            log_silent "Services healthy after ${elapsed}s"
            return 0
        fi
        sleep 10
        elapsed=$((elapsed + 10))
    done
    log_silent "Services not fully healthy after ${budget}s; proceeding"
    return 0
}

# Check service status
check_services() {
    log_silent "Verifying AI Architect services..."

    cd "$NEW_DIR" || exit 1

    local running_count=$(docker ps --filter "name=ai-architect" --filter "status=running" --format "{{.Names}}" 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$running_count" -gt 0 ]]; then
        log_silent "Found $running_count service(s) running"
        docker ps --filter "name=ai-architect" --format "table {{.Names}}\t{{.Status}}" 2>/dev/null \
            | grep -v "temporal" | head -11 >> "$LOG_FILE" 2>&1
    else
        msg_warn "No services appear to be running yet - they may still be starting"
        msg_info "Check status: bitoarch status"
    fi
}

# Check if old services are running
check_old_services_running() {
    cd "$OLD_DIR" || return 1

    local running_count
    running_count=$(docker ps --filter "name=ai-architect" --format "{{.Names}}" 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$running_count" -gt 0 ]]; then
        log_silent "Found $running_count old service(s) running"
        return 0
    fi
    return 1
}

# Stop old version using setup.sh --stop (EMBEDDED MODE)
stop_old_version() {
    if ! check_old_services_running; then
        log_silent "Old services not running, skipping stop"
        return 0
    fi

    cd "$OLD_DIR" || exit 1

    if ./setup.sh --stop >> "$LOG_FILE" 2>&1; then
        log_silent "Old version stopped"
    else
        msg_warn "Some issues stopping old version"
    fi
}

# Stop old version - STANDALONE MODE (direct docker commands)
stop_old_version_standalone() {
    log_silent "Stopping old version services..."
    
    local old_containers=$(docker ps --filter "name=ai-architect" --format "{{.Names}}" 2>/dev/null)
    
    if [[ -n "$old_containers" ]]; then
        log_silent "Stopping old containers..."
        log_silent "Containers to stop: $old_containers"
        echo "$old_containers" | xargs -r docker stop >> "$LOG_FILE" 2>&1
        log_silent "Old version stopped"
    else
        log_silent "No old containers running, skipping stop"
    fi
}

# Kubernetes upgrade functions
upgrade_kubernetes() {
    msg_info "Starting Kubernetes upgrade..."
    
    local namespace="bito-ai-architect"
    
    # Check if Helm release exists
    if ! helm list -n "$namespace" | grep -q "bitoarch"; then
        msg_error "Helm release 'bitoarch' not found in namespace $namespace"
        msg_info "This doesn't appear to be a Kubernetes deployment"
        exit 1
    fi
    
    cd "$NEW_DIR" || exit 1
    
    # Copy deployment type marker
    echo "kubernetes" > "${NEW_DIR}/.deployment-type"
    
    # Regenerate Helm values from migrated .env file
    msg_info "Generating Helm values from configuration..."
    
    # Set SCRIPT_DIR for values-generator.sh
    export SCRIPT_DIR="$NEW_DIR"
    
    # CRITICAL: Determine standard config directory BEFORE sourcing path-manager.sh
    # This prevents path-manager's auto init_paths from detecting "legacy" layout
    local standard_config_dir
    if [[ -d "/usr/local/etc/bitoarch" ]]; then
        standard_config_dir="/usr/local/etc/bitoarch"
    elif [[ -d "${HOME}/.local/bitoarch/etc" ]]; then
        standard_config_dir="${HOME}/.local/bitoarch/etc"
    else
        # Neither exists - determine based on permissions (same as fresh install logic)
        if [[ -w "/usr/local/etc" ]] || command -v sudo >/dev/null 2>&1; then
            standard_config_dir="/usr/local/etc/bitoarch"
        else
            standard_config_dir="${HOME}/.local/bitoarch/etc"
        fi
    fi
    
    # Set path variables for values-generator.sh
    export BITOARCH_CONFIG_DIR="$standard_config_dir"
    # Also set VAR_DIR based on the chosen standard config path
    if [[ "$standard_config_dir" == "/usr/local/etc/bitoarch" ]]; then
        export BITOARCH_VAR_DIR="/usr/local/var/bitoarch"
    else
        export BITOARCH_VAR_DIR="${HOME}/.local/bitoarch/var"
    fi
    
    # NOTE: We don't source path-manager.sh here for K8s upgrades because:
    # 1. We don't use any of its functions (no get_config_dir calls)
    # 2. It would auto-call init_paths and override our BITOARCH_CONFIG_DIR setting
    # 3. We've already set all the required environment variables above

    mkdir -p "$standard_config_dir"

    # Copy configs to standard location; remove from NEW_DIR (K8s reads from standard path).
    for config_file in .env-bitoarch .env-llm-bitoarch .bitoarch-config.yaml .deployment-type; do
        if [[ -f "${NEW_DIR}/${config_file}" ]] && [[ "${NEW_DIR}" != "${standard_config_dir}" ]]; then
            cp "${NEW_DIR}/${config_file}" "$standard_config_dir/${config_file}"
            rm -f "${NEW_DIR}/${config_file}"
        fi
    done
    log_silent "Configs synced to $standard_config_dir"

    # Update bitoarch CLI symlink to new installation.
    # Must use scripts/bitoarch.sh (correctly resolves lib/ via scripts/), not root bitoarch.
    local cli_bin_dir="$HOME/.local/bin"
    local cli_target="$cli_bin_dir/bitoarch"
    local cli_source="${NEW_DIR}/scripts/bitoarch.sh"

    if [[ -f "$cli_source" ]]; then
        mkdir -p "$cli_bin_dir"
        chmod +x "$cli_source"
        ln -sf "$cli_source" "$cli_target"
        msg_success "CLI symlink updated: $cli_target"
    else
        msg_warn "bitoarch CLI not found in new installation, skipping symlink update"
    fi

    # Source the values-generator and call with imagePullPolicy=Always
    # shellcheck disable=SC1090
    source "${NEW_DIR}/scripts/values-generator.sh"

    # Execute values-generator function with Always pull policy for upgrades
    if ! generate_k8s_values_from_env "Always" 2>&1 | tee -a "$LOG_FILE"; then
        msg_error "Failed to generate Helm values"
        msg_error "Check log file for details: $LOG_FILE"
        tail -20 "$LOG_FILE" | grep -i "error" || tail -20 "$LOG_FILE"
        exit 1
    fi

    # Verify values file was created (check standard location after migration)
    local values_file="${standard_config_dir}/.bitoarch-values.yaml"
    if [[ ! -f "$values_file" ]]; then
        msg_error "Helm values file not generated"
        msg_error "Expected location: $values_file"
        msg_error "The values-generator.sh script completed but didn't create the output file"
        exit 1
    fi
    
    msg_info "Using values file: $values_file"

    # Perform Helm upgrade
    msg_info "Upgrading Helm release..."
    msg_info "This may take 2-5 minutes (pulling images, updating pods)..."
    
    if helm upgrade bitoarch "${NEW_DIR}/helm-bitoarch" \
        --namespace "$namespace" \
        --values "$values_file" \
        --wait \
        --timeout 10m >> "$LOG_FILE" 2>&1; then
        msg_success "Helm upgrade completed"

        # Force rollout restart so pods pull latest images (imagePullPolicy=Always).
        # Needed when upgrading to the same version with an updated image in the registry.
        kubectl rollout restart deployment -n "$namespace" -l "app.kubernetes.io/name=bitoarch" >> "$LOG_FILE" 2>&1 || true
        kubectl rollout restart statefulset -n "$namespace" -l "app.kubernetes.io/name=bitoarch" >> "$LOG_FILE" 2>&1 || true

        log_silent "Pod rollout initiated to force image pull"

        # CRITICAL: Wait for ALL rollouts to complete before starting port-forwards
        # This prevents race condition where port-forward connects to terminating pod
        msg_info "Waiting for all deployment rollouts to complete..."
        for component in provider manager config tracker mysql worker; do
            log_silent "  Waiting for ai-architect-${component} rollout..."
            if kubectl rollout status deployment/ai-architect-${component} -n "$namespace" --timeout=180s >> "$LOG_FILE" 2>&1; then
                msg_success "  ai-architect-${component} rolled out"
            else
                msg_warn "  ai-architect-${component} rollout did not complete"
            fi
        done
        # Temporal is a StatefulSet, not a Deployment
        log_silent "Waiting for ai-architect-temporal rollout..."
        if kubectl rollout status statefulset/ai-architect-temporal -n "$namespace" --timeout=180s >> "$LOG_FILE" 2>&1; then
            log_silent "Rollout complete: ai-architect-temporal"
        else
            log_silent "Rollout may not have completed for ai-architect-temporal"
        fi
        msg_success "All deployment rollouts completed"
    else
        msg_error "Helm upgrade failed"
        msg_error "Check log file for details: $LOG_FILE"
        echo ""
        tail -50 "$LOG_FILE"
        echo ""
        msg_info "To rollback: helm rollback bitoarch -n $namespace"
        exit 1
    fi

    # Wait for pods ready after rollout restart.
    # Inlined to work regardless of kubernetes-manager.sh version in old installation.
    msg_info "Waiting for pods to be ready..."
    local max_wait=180
    local waited=0
    local services=("mysql" "config" "manager" "provider" "tracker" "temporal" "worker")

    while [ $waited -lt $max_wait ]; do
        local all_ready=true
        for service in "${services[@]}"; do
            local ready=$(kubectl get pods -n "$namespace" -l "app.kubernetes.io/component=$service" \
                -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
            if [ "$ready" != "True" ]; then
                all_ready=false
                break
            fi
        done

        if [ "$all_ready" = true ]; then
            msg_success "All pods are ready"
            break
        fi

        echo -n "."
        sleep 5
        waited=$((waited + 5))
    done

    if [ $waited -ge $max_wait ]; then
        msg_warn "Some pods may still be initializing"
    fi
    echo ""

    # Load environment variables from standard location for port configuration
    # (configs were moved to standard location, not in NEW_DIR anymore)
    set -a
    source "${standard_config_dir}/.env-bitoarch" 2>/dev/null || true
    set +a

    # Setup port-forwards for immediate CLI access
    # INLINE implementation to work regardless of kubernetes-manager.sh version in old installation
    msg_info "Setting up port-forwards to new pods..."

    # Kill any existing port-forwards
    pkill -f "kubectl.*port-forward.*${namespace}" 2>/dev/null || true
    sleep 2

    # Read port configuration
    local provider_ext="${CIS_PROVIDER_EXTERNAL_PORT:-5001}"
    local manager_ext="${CIS_MANAGER_EXTERNAL_PORT:-5002}"
    local config_ext="${CIS_CONFIG_EXTERNAL_PORT:-5003}"
    local mysql_ext="${MYSQL_EXTERNAL_PORT:-5004}"
    local tracker_ext="${CIS_TRACKER_EXTERNAL_PORT:-5005}"
    local temporal_ext="${TEMPORAL_EXTERNAL_PORT:-5006}"

    local provider_int="${XMCP_HTTP_PORT:-8080}"
    local manager_int="${CIS_MANAGER_PORT:-9090}"
    local config_int="${CIS_CONFIG_PORT:-8081}"
    local mysql_int="${MYSQL_PORT:-3306}"
    local tracker_int="${CIS_TRACKING_PORT:-9920}"
    local temporal_int="${TEMPORAL_PORT:-7233}"

    # Launch port-forwards with proper daemonization
    # Use: nohup + stdin from /dev/null + disown to fully detach from shell
    nohup kubectl port-forward --address 0.0.0.0 -n "$namespace" svc/ai-architect-provider "${provider_ext}:${provider_int}" </dev/null >> "$LOG_FILE" 2>&1 &
    disown 2>/dev/null || true
    sleep 0.5

    nohup kubectl port-forward --address 0.0.0.0 -n "$namespace" svc/ai-architect-manager "${manager_ext}:${manager_int}" </dev/null >> "$LOG_FILE" 2>&1 &
    disown 2>/dev/null || true
    sleep 0.5

    nohup kubectl port-forward --address 0.0.0.0 -n "$namespace" svc/ai-architect-config "${config_ext}:${config_int}" </dev/null >> "$LOG_FILE" 2>&1 &
    disown 2>/dev/null || true
    sleep 0.5

    nohup kubectl port-forward --address 0.0.0.0 -n "$namespace" svc/ai-architect-mysql "${mysql_ext}:${mysql_int}" </dev/null >> "$LOG_FILE" 2>&1 &
    disown 2>/dev/null || true
    sleep 0.5

    nohup kubectl port-forward --address 0.0.0.0 -n "$namespace" svc/ai-architect-tracker "${tracker_ext}:${tracker_int}" </dev/null >> "$LOG_FILE" 2>&1 &
    disown 2>/dev/null || true
    sleep 0.5

    nohup kubectl port-forward --address 0.0.0.0 -n "$namespace" svc/ai-architect-temporal "${temporal_ext}:${temporal_int}" </dev/null >> "$LOG_FILE" 2>&1 &
    disown 2>/dev/null || true
    sleep 2

    # Verify and retry port-forwards with health check
    local max_verify_attempts=3
    local verify_attempt=1

    while [ $verify_attempt -le $max_verify_attempts ]; do
        local pf_count=$(ps aux | grep "kubectl port-forward" | grep -E "(-n |--namespace=|-n=)$namespace" | grep -v grep | wc -l | xargs)

        if [ "$pf_count" -ge 6 ]; then
            msg_success "Port-forwards established"
            break
        fi

        # Retry progress: keep counts in log, not terminal.
        log_silent "Only $pf_count/6 port-forwards running (attempt $verify_attempt)"

        # Restart missing port-forwards
        if ! ps aux | grep "kubectl port-forward" | grep "ai-architect-provider" | grep -v grep >/dev/null 2>&1; then
            log_silent "Restarting provider port-forward"
            nohup kubectl port-forward --address 0.0.0.0 -n "$namespace" svc/ai-architect-provider "${provider_ext}:${provider_int}" </dev/null >> "$LOG_FILE" 2>&1 &
            disown 2>/dev/null || true
        fi

        if ! ps aux | grep "kubectl port-forward" | grep "ai-architect-manager" | grep -v grep >/dev/null 2>&1; then
            log_silent "Restarting manager port-forward"
            nohup kubectl port-forward --address 0.0.0.0 -n "$namespace" svc/ai-architect-manager "${manager_ext}:${manager_int}" </dev/null >> "$LOG_FILE" 2>&1 &
            disown 2>/dev/null || true
        fi

        if ! ps aux | grep "kubectl port-forward" | grep "ai-architect-config" | grep -v grep >/dev/null 2>&1; then
            log_silent "Restarting config port-forward"
            nohup kubectl port-forward --address 0.0.0.0 -n "$namespace" svc/ai-architect-config "${config_ext}:${config_int}" </dev/null >> "$LOG_FILE" 2>&1 &
            disown 2>/dev/null || true
        fi

        if ! ps aux | grep "kubectl port-forward" | grep "ai-architect-mysql" | grep -v grep >/dev/null 2>&1; then
            log_silent "Restarting mysql port-forward"
            nohup kubectl port-forward --address 0.0.0.0 -n "$namespace" svc/ai-architect-mysql "${mysql_ext}:${mysql_int}" </dev/null >> "$LOG_FILE" 2>&1 &
            disown 2>/dev/null || true
        fi

        if ! ps aux | grep "kubectl port-forward" | grep "ai-architect-tracker" | grep -v grep >/dev/null 2>&1; then
            log_silent "Restarting tracker port-forward"
            nohup kubectl port-forward --address 0.0.0.0 -n "$namespace" svc/ai-architect-tracker "${tracker_ext}:${tracker_int}" </dev/null >> "$LOG_FILE" 2>&1 &
            disown 2>/dev/null || true
        fi

        if ! ps aux | grep "kubectl port-forward" | grep "ai-architect-temporal" | grep -v grep >/dev/null 2>&1; then
            log_silent "Restarting temporal port-forward"
            nohup kubectl port-forward --address 0.0.0.0 -n "$namespace" svc/ai-architect-temporal "${temporal_ext}:${temporal_int}" </dev/null >> "$LOG_FILE" 2>&1 &
            disown 2>/dev/null || true
        fi

        sleep 2
        verify_attempt=$((verify_attempt + 1))
    done

    # Final connectivity check — and recreate any HTTP forward that doesn't
    # answer (free the port + relaunch, mirroring restart_port_forward) instead
    # of only warning. mysql/temporal aren't HTTP-probeable, so they're left
    # best-effort. Inline (no sourcing) to work regardless of the old install's
    # kubernetes-manager.sh version.
    msg_info "Verifying port-forward connectivity..."
    local unhealthy=() hc_spec hc_svc hc_ext hc_int hc_ok hc_attempt
    # HTTP services to health-check + recreate (mysql/temporal aren't HTTP).
    local hc_specs=(
        "ai-architect-provider:${provider_ext}:${provider_int}"
        "ai-architect-manager:${manager_ext}:${manager_int}"
        "ai-architect-config:${config_ext}:${config_int}"
        "ai-architect-tracker:${tracker_ext}:${tracker_int}"
    )
    for hc_spec in "${hc_specs[@]}"; do
        IFS=: read -r hc_svc hc_ext hc_int <<< "$hc_spec"
        hc_ok=false
        for hc_attempt in 1 2 3; do
            if curl -s --connect-timeout 2 "http://localhost:${hc_ext}/health" >/dev/null 2>&1; then
                hc_ok=true; break
            fi
            log_silent "Port ${hc_ext} (${hc_svc}) not answering; recreating (attempt ${hc_attempt})"
            pkill -9 -f "kubectl port-forward.*svc/${hc_svc} .*${hc_ext}:" 2>/dev/null || true
            if command -v lsof >/dev/null 2>&1; then
                local hc_holders; hc_holders=$(lsof -ti :"${hc_ext}" -sTCP:LISTEN 2>/dev/null)
                [ -n "$hc_holders" ] && { echo "$hc_holders" | xargs kill -9 2>/dev/null || true; }
            fi
            sleep 1
            nohup kubectl port-forward --address 0.0.0.0 -n "$namespace" "svc/${hc_svc}" "${hc_ext}:${hc_int}" </dev/null >> "$LOG_FILE" 2>&1 &
            disown 2>/dev/null || true
            sleep 1
        done
        [ "$hc_ok" = true ] || unhealthy+=("$hc_svc")
    done

    if [ ${#unhealthy[@]} -eq 0 ]; then
        msg_success "All port-forwards healthy and responding"
    else
        msg_warn "Port-forwards still unreachable after retry: ${unhealthy[*]}"
        msg_info "Recover with: bitoarch restart"
    fi
}

# Check Kubernetes deployment status
check_kubernetes_services() {
    msg_info "Verifying Kubernetes deployment..."
    
    local namespace="bito-ai-architect"
    
    # Wait for pods to be ready
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        local ready_pods=$(kubectl get pods -n "$namespace" -o jsonpath='{range .items[?(@.status.conditions[?(@.type=="Ready")].status=="True")]}{.metadata.name}{"\n"}{end}' 2>/dev/null | wc -l | xargs)
        local total_pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | wc -l | xargs)
        
        if [ "$ready_pods" -eq "$total_pods" ] && [ "$total_pods" -gt 0 ]; then
            break
        fi
        
        if [ $attempt -eq 1 ]; then
            msg_info "Waiting for pods to be ready..."
        fi
        
        echo -n "."
        sleep 10
        attempt=$((attempt + 1))
    done
    echo ""
    
    if [ $attempt -gt $max_attempts ]; then
        msg_warn "Timeout waiting for all pods to be ready"
    else
        msg_success "All pods are ready ($ready_pods/$total_pods)"
    fi
    
    # Show pod status
    echo ""
    kubectl get pods -n "$namespace" 2>/dev/null | grep -v "temporal" | head -11
    echo ""
}

# Run MySQL init scripts that are normally only executed on first boot.
# During upgrades, MySQL skips /docker-entrypoint-initdb.d/ because the data
# directory already exists. This function runs every init script blindly so
# temporal_user, databases, and schema history tables exist when temporal/worker
# pods come up. Init scripts are written to be idempotent (IF NOT EXISTS), so
# re-running them is safe.
run_mysql_init_prerequisites() {
    msg_info "Running MySQL init prerequisites..."

    export DEPLOYMENT_TYPE

    # Source env file for MySQL credentials
    if [[ -f "${NEW_DIR}/.env-bitoarch" ]]; then
        # shellcheck disable=SC1090
        source "${NEW_DIR}/.env-bitoarch"
    elif [[ -f "$OLD_ENV" ]]; then
        # shellcheck disable=SC1090
        source "$OLD_ENV"
    fi

    if [[ -z "${MYSQL_ROOT_PASSWORD:-}" ]]; then
        msg_warn "MYSQL_ROOT_PASSWORD not set, skipping MySQL init prerequisites"
        return 0
    fi

    # Inline MySQL exec helpers — defined here so we don't depend on
    # the package's sql-migration-manager.sh having these functions.
    _init_exec_sql_file() {
        local sql_file="$1"
        if [[ "$DEPLOYMENT_TYPE" == "kubernetes" ]]; then
            kubectl exec -i -n bito-ai-architect deployment/ai-architect-mysql -- \
                mysql -u root -p"${MYSQL_ROOT_PASSWORD}" < "$sql_file"
        else
            docker exec -i ai-architect-mysql \
                mysql -u root -p"${MYSQL_ROOT_PASSWORD}" < "$sql_file"
        fi
    }

    _init_exec_shell_script() {
        local script_file="$1"
        if [[ "$DEPLOYMENT_TYPE" == "kubernetes" ]]; then
            kubectl exec -i -n bito-ai-architect deployment/ai-architect-mysql -- \
                env MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}" \
                    TEMPORAL_MYSQL_USER="${TEMPORAL_MYSQL_USER:-temporal_user}" \
                    TEMPORAL_MYSQL_PASSWORD="${TEMPORAL_MYSQL_PASSWORD:-}" \
                bash < "$script_file"
        else
            docker exec -i \
                -e MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}" \
                -e TEMPORAL_MYSQL_USER="${TEMPORAL_MYSQL_USER:-temporal_user}" \
                -e TEMPORAL_MYSQL_PASSWORD="${TEMPORAL_MYSQL_PASSWORD:-}" \
                ai-architect-mysql \
                bash < "$script_file"
        fi
    }

    # Determine init directory based on deployment type
    local init_dir
    if [[ "$DEPLOYMENT_TYPE" == "kubernetes" ]]; then
        init_dir="${NEW_DIR}/helm-bitoarch/services/mysql/init"
    else
        init_dir="${NEW_DIR}/services/mysql/init"
    fi

    if [[ ! -d "$init_dir" ]]; then
        log_silent "MySQL init directory not found at $init_dir, skipping"
        log_silent "[prereq] Init dir not found: $init_dir"
        return 0
    fi

    log_silent "  [prereq] Init dir:   $init_dir"
    log_silent "  [prereq] Deployment: ${DEPLOYMENT_TYPE:-docker-compose}"
    log_silent "  [prereq] Root pw set: $([[ -n "${MYSQL_ROOT_PASSWORD:-}" ]] && echo 'yes' || echo 'NO — will fail')"

    local pending_count=0
    local failed_count=0

    # Process files in sorted order (Docker convention: 00-, 01-, 02-)
    for init_file in $(ls "$init_dir"/* 2>/dev/null | sort); do
        local filename=$(basename "$init_file")

        # Skip non-script files
        case "$filename" in
            *.sql) ;;
            *.sh)  ;;
            *) log_silent "Skipping non-script file: $filename"; continue ;;
        esac

        log_silent "  [prereq] RUN: $filename"
        log_silent "Running init script: $filename"
        local script_success=false
        local exec_output

        if [[ "$filename" == *.sql ]]; then
            if exec_output=$(_init_exec_sql_file "$init_file" 2>&1); then
                script_success=true
            fi
        elif [[ "$filename" == *.sh ]]; then
            if exec_output=$(_init_exec_shell_script "$init_file" 2>&1); then
                script_success=true
            fi
        fi

        # Always log full output to log file
        if [[ -n "$exec_output" ]]; then
            echo "$exec_output" >> "$LOG_FILE"
        fi

        if [[ "$script_success" == "true" ]]; then
            log_silent "[prereq] OK: $filename"
            log_silent "Init script applied: $filename"
            pending_count=$((pending_count + 1))
        else
            msg_warn "  [prereq] FAILED: $filename"
            if [[ -n "$exec_output" ]]; then
                # Print first relevant error line to terminal for quick diagnosis
                local first_error
                first_error=$(echo "$exec_output" | grep -i "error\|denied\|failed\|warn" | head -3)
                if [[ -n "$first_error" ]]; then
                    msg_warn "  [prereq]   → $first_error"
                fi
            fi
            log_silent "Init script $filename failed"
            failed_count=$((failed_count + 1))

            # 02-create-temporal-user.sh is load-bearing: Temporal and Worker
            # both authenticate as temporal_user. Without it they will
            # CrashLoopBackOff a few minutes later with a misleading auth
            # error. Abort the upgrade here with a clear root cause.
            if [[ "$filename" == "02-create-temporal-user.sh" ]]; then
                critical_failed=true
            fi
        fi
    done

    if [[ "${critical_failed:-false}" == "true" ]]; then
        msg_error "MySQL init prerequisite '02-create-temporal-user.sh' failed — Temporal/Worker require temporal_user to exist."
        msg_error "Aborting upgrade. Fix the error above (commonly a missing TEMPORAL_MYSQL_PASSWORD in .env-bitoarch) and retry."
        return 1
    fi

    if [[ $failed_count -gt 0 ]]; then
        msg_warn "MySQL init prerequisites: $failed_count script(s) failed (check log for details)"
    else
        msg_success "MySQL init prerequisites completed ($pending_count script(s) applied)"
    fi

    return 0
}

# Run database migrations from NEW version's scripts
run_database_migrations() {
    log_silent "Running database migrations from new version..."
    
    # Source the NEW version's sql-migration-manager.sh
    local migration_script="${NEW_DIR}/scripts/sql-migration-manager.sh"
    
    if [[ ! -f "$migration_script" ]]; then
        log_silent "Migration script not found, skipping database migrations"
        return 0
    fi
    
    # Export DEPLOYMENT_TYPE for migration script
    export DEPLOYMENT_TYPE
    
    # Source the migration script (which sources setup-utils.sh for print_* functions)
    # shellcheck disable=SC1090
    source "$migration_script"
    
    # Update SQL_MIGRATION_PLATFORM_DIR to point to NEW installation
    SQL_MIGRATION_PLATFORM_DIR="$NEW_DIR"
    
    # Run migrations (stdout/stderr → LOG_FILE; terminal stays quiet)
    if run_upgrade_migrations >> "$LOG_FILE" 2>&1; then
        log_silent "Database migrations completed"
    else
        msg_error "Database migrations failed"
        return 1
    fi
    
    return 0
}

_version_lt() {
    local IFS='.'
    local i v1=($1) v2=($2)
    for ((i=0; i<3; i++)); do
        local a=${v1[i]:-0} b=${v2[i]:-0}
        (( a < b )) && return 0
        (( a > b )) && return 1
    done
    return 1
}

_resolve_new_version() {
    local v=""
    if [[ -f "${NEW_DIR}/versions/service-versions.json" ]]; then
        v=$(jq -r '.platform_info.version // empty' "${NEW_DIR}/versions/service-versions.json" 2>/dev/null)
    fi
    [[ -z "$v" || "$v" == "null" ]] && v="${TARGET_VERSION:-unknown}"
    echo "$v"
}

_print_insights_announcement() {
    if _version_lt "${CURRENT_VERSION:-0.0.0}" "1.8.4"; then
        echo ""
        echo -e "  ${GREEN}──────────────────────────────────────────────────────${NC}"
        echo -e "  ${GREEN}NEW:${NC} Insights — analyze Git history, tickets, and docs."
        echo -e "  Get started:"
        echo -e "    ${YELLOW}bitoarch insights enable git${NC}"
        echo -e "    ${YELLOW}bitoarch insights enable ticket-tracker${NC}"
        echo -e "    ${YELLOW}bitoarch insights run${NC}"
        echo -e "  ${GREEN}──────────────────────────────────────────────────────${NC}"
        echo ""
    fi
}

print_kubernetes_success() {
    local new_version
    new_version=$(_resolve_new_version)
    print_header "✅ AI Architect Upgrade Complete [Version: ${new_version}]"

    echo -e "${GREEN}✓ Upgrade successful${NC}"
    echo ""
    echo -e "Next steps:"
    echo -e "   ${BLUE}cd ${NEW_DIR}${NC}"
    echo -e "   ${YELLOW}bitoarch status${NC}"
    echo -e "   ${YELLOW}bitoarch index-status${NC}"
    echo ""
    _print_insights_announcement
    echo -e "Log:      ${LOG_FILE}"
    echo -e "Cleanup:  ${YELLOW}rm -rf ${OLD_DIR}${NC}  (after verifying new version)"
    echo ""
    echo -e "${YELLOW}Note: rollback is not supported after a successful upgrade.${NC}"
    echo ""
}

# Cleanup temporary files
cleanup() {
    [[ -d "$TEMP_DOWNLOAD_DIR" ]] && rm -rf "$TEMP_DOWNLOAD_DIR"
}

trap cleanup EXIT

print_success() {
    local new_version
    new_version=$(_resolve_new_version)
    print_header "✅ AI Architect Upgrade Complete [Version: ${new_version}]"

    echo -e "${GREEN}✓ Upgrade successful${NC}"
    echo ""
    echo -e "Next steps:"
    echo -e "   ${BLUE}cd ${NEW_DIR}${NC}"
    echo -e "   ${YELLOW}bitoarch status${NC}"
    echo ""
    _print_insights_announcement
    echo -e "Log:      ${LOG_FILE}"
    echo -e "Cleanup:  ${YELLOW}rm -rf ${OLD_DIR}${NC}  (after verifying new version)"
    echo ""
    echo -e "${YELLOW}Note: rollback is not supported after a successful upgrade.${NC}"
    echo ""
}

# Main execution
main() {
    print_header "🔄 BITO's AI Architect Upgrade"

    parse_args "$@"

    # Promote LOG_FILE to the canonical setup.log (path-manager-resolved)
    # once OLD_DIR is known so all phases land in the same file the rest of
    # the platform uses. Falls back to the per-PID tmp log if path-manager
    # isn't sourceable from OLD_DIR (very old installs).
    if [ -f "${OLD_DIR}/scripts/lib/path-manager.sh" ]; then
        # shellcheck disable=SC1091
        ( source "${OLD_DIR}/scripts/lib/path-manager.sh"; init_paths 2>/dev/null; get_log_dir 2>/dev/null ) >/tmp/.bitoarch-logdir-$$ 2>/dev/null || true
        local _logdir
        _logdir=$(cat /tmp/.bitoarch-logdir-$$ 2>/dev/null | tail -1)
        rm -f /tmp/.bitoarch-logdir-$$ 2>/dev/null
        if [ -n "$_logdir" ] && mkdir -p "$_logdir" 2>/dev/null && [ -w "$_logdir" ]; then
            LOG_FILE="${_logdir}/setup.log"
        fi
    fi

    log_silent "=== Upgrade Started ==="
    log_silent "OLD_DIR: ${OLD_DIR}"
    log_silent "Target version: ${TARGET_VERSION}"
    log_silent "Custom URL: ${CUSTOM_URL:-none}"

    # Pre-flight checks
    check_prerequisites
    verify_old_installation
    check_indexing_not_running

    if [[ -f "${OLD_DIR}/versions/service-versions.json" ]]; then
        local current_version=$(jq -r '.platform_info.version // "unknown"' "${OLD_DIR}/versions/service-versions.json" 2>/dev/null)
        if [[ "$current_version" == "$TARGET_VERSION" ]]; then
            msg_warn "Already on version $TARGET_VERSION"
            exit 0
        fi
    fi

    # Download and extract
    local tarball_path
    local version_name

    if [[ -n "$CUSTOM_URL" ]]; then
        version_name=$(basename "$CUSTOM_URL" .tar.gz | sed 's/^bito-ai-architect-//')
        tarball_path=$(download_package "$version_name" "$CUSTOM_URL")
    else
        version_name="$TARGET_VERSION"
        local download_url
        if [[ "$TARGET_VERSION" == "latest" ]]; then
            download_url="${DOWNLOAD_BASE_URL}/latest/bito-ai-architect-latest.tar.gz"
        else
            download_url="${DOWNLOAD_BASE_URL}/${TARGET_VERSION}/bito-ai-architect-${TARGET_VERSION}.tar.gz"
        fi
        tarball_path=$(download_package "$version_name" "$download_url")
    fi

    extract_package "$tarball_path" "$version_name"

    # Configure and deploy
    migrate_config
    
    # Run MySQL init prerequisites before starting/upgrading services.
    # Creates temporal_user, databases, schema history tables etc. that are
    # normally created by MySQL init scripts on first boot only.
    if ! run_mysql_init_prerequisites; then
        exit 1
    fi

    # CLI relink + MCP cert prep — all modes.
    prepare_new_install_artifacts

    if [[ "$UPGRADE_MODE" == "kubernetes" ]]; then
        # Kubernetes mode: Helm upgrade with rolling update
        upgrade_kubernetes
        check_kubernetes_services
        run_database_migrations
        print_kubernetes_success
    elif [[ "$UPGRADE_MODE" == "standalone" ]]; then
        # Standalone mode: stop old, start new (deploy+health under spinner), verify
        stop_old_version_standalone
        start_new_version_standalone
        check_services
        run_database_migrations
        print_success
    else
        # Embedded mode: start new (deploy+health under spinner), verify, stop old
        start_new_version
        check_services
        run_database_migrations
        stop_old_version
        print_success
    fi

    # Standalone auto-recovery hooks (BITO-13219). Each hook self-gates on
    # its own flag (auto_recovery_enabled, MCP_TRANSPORT, etc.), so
    # Enterprise / K8s installs no-op the Standalone-only ones.
    run_post_install_hooks

    log_silent "=== Upgrade Completed Successfully ==="
    log_silent "New installation: $NEW_DIR"
}

# Only run main when executed directly; sourcing (e.g., from tests) loads the
# function definitions without triggering the upgrade flow.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
