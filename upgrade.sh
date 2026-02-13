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

print_header() {
    echo "" | tee -a "$LOG_FILE"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}$1${NC}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
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
show_usage() {
    cat << EOF
Bito AI Architect Blue/Green Upgrade Script (Unified)

Usage: $0 [options]

Auto-detects version and uses appropriate upgrade method:
  • Version 1.0.0: Uses direct docker compose commands
  • Version >1.0.0: Uses setup.sh with --from-existing-config

Options:
  --old-path=PATH      Path to existing installation (required if not run from within installation)
  --version=VERSION    Upgrade to specific version (e.g., 1.1.0, 2.0.0)
  --url=URL            Upgrade from custom tarball URL
  --help               Show this help message

Examples:
  # From within installation directory (auto-detect):
  cd /path/to/installation
  ./scripts/upgrade.sh --version=2.0.0

  # From independent directory:
  ./upgrade.sh --old-path=/path/to/installation --version=2.0.0

  # From custom URL:
  ./upgrade.sh --old-path=/path/to/installation --url=file:///path/to/package.tar.gz

Features:
  • Zero downtime (blue/green deployment)
  • Data preservation (MySQL, volumes, configs)
  • Automatic version detection and method selection
  • Works with all versions (1.0.0 and newer)

EOF
}

# Detect deployment type
detect_deployment_type() {
    # Check multiple locations for .deployment-type file
    # For 1.4.x+: file is in /usr/local or ~/.local (standard paths)
    # For older versions (1.3.x): file is in OLD_DIR
    local deployment_type_file=""
    
    if [[ -f "${OLD_DIR}/.deployment-type" ]] && [[ ! -L "${OLD_DIR}/.deployment-type" ]]; then
        # Regular file in OLD_DIR (1.3.x or older)
        deployment_type_file="${OLD_DIR}/.deployment-type"
        log_silent "Found .deployment-type in OLD_DIR (regular file)"
    elif [[ -f "/usr/local/etc/bitoarch/.deployment-type" ]]; then
        deployment_type_file="/usr/local/etc/bitoarch/.deployment-type"
        log_silent "Found .deployment-type in /usr/local/etc/bitoarch"
    elif [[ -f "${HOME}/.local/bitoarch/etc/.deployment-type" ]]; then
        deployment_type_file="${HOME}/.local/bitoarch/etc/.deployment-type"
        log_silent "Found .deployment-type in ~/.local/bitoarch/etc"
    fi
    
    if [[ -n "$deployment_type_file" ]]; then
        DEPLOYMENT_TYPE=$(cat "$deployment_type_file")
        msg_info "Detected deployment type: $DEPLOYMENT_TYPE"
        log_silent "Deployment type from $deployment_type_file: $DEPLOYMENT_TYPE"
    else
        DEPLOYMENT_TYPE="docker-compose"
        msg_info "No deployment type marker found, assuming: docker-compose"
        log_silent "Defaulting to docker deployment type"
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
    
    # Determine OLD_DIR
    if [[ -n "$CUSTOM_OLD_PATH" ]]; then
        # User provided --old-path (expand tilde if present)
        OLD_DIR="${CUSTOM_OLD_PATH/#\~/$HOME}"
        msg_info "Using provided installation path: $OLD_DIR"
    else
        # Try to detect from script location
        OLD_DIR="$(dirname "$SCRIPT_DIR")"
        
        # Check if this looks like an installation directory
        if [[ ! -f "${OLD_DIR}/.env-bitoarch" ]]; then
            # Not run from within installation, prompt for path
            echo ""
            msg_warn "Script is not running from within an installation directory"
            msg_info "Please provide the path to your existing installation"
            echo ""
            read -p "Enter path to existing installation: " OLD_DIR
            
            if [[ -z "$OLD_DIR" ]] || [[ ! -d "$OLD_DIR" ]]; then
                msg_error "Invalid installation path"
                exit 1
            fi
            
            if [[ ! -f "${OLD_DIR}/.env-bitoarch" ]]; then
                msg_error "Not a valid installation directory (missing .env-bitoarch)"
                exit 1
            fi
        fi
    fi
    
    PARENT_DIR="$(dirname "$OLD_DIR")"
    OLD_ENV="${OLD_DIR}/.env-bitoarch"
    
    # Detect deployment type first
    detect_deployment_type
    
    # Detect current version and determine upgrade mode
    detect_current_version "$OLD_DIR"
    
    # Determine upgrade mode based on deployment type and version
    if [[ "$DEPLOYMENT_TYPE" == "kubernetes" ]]; then
        UPGRADE_MODE="kubernetes"
        msg_info "Using Kubernetes upgrade mode (helm upgrade)"
    elif [[ "$CURRENT_VERSION" == "1.0.0" ]]; then
        UPGRADE_MODE="standalone"
        msg_info "Detected version 1.0.0 - using standalone mode (direct docker compose)"
    elif [[ "$CURRENT_VERSION" == "unknown" ]]; then
        UPGRADE_MODE="embedded"
        msg_warn "Version unknown - defaulting to embedded mode (setup.sh)"
    else
        UPGRADE_MODE="embedded"
        msg_info "Detected version $CURRENT_VERSION - using embedded mode (setup.sh)"
    fi
    
    log_silent "Upgrade mode: $UPGRADE_MODE"
    
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
        
        # Detect docker compose command for standalone mode
        if [[ "$UPGRADE_MODE" == "standalone" ]]; then
            DOCKER_COMPOSE_CMD=$(detect_docker_compose)
            if [[ -z "$DOCKER_COMPOSE_CMD" ]]; then
                msg_error "Docker Compose not found (tried 'docker compose' and 'docker-compose')"
                exit 1
            fi
            log_silent "Using docker compose command: $DOCKER_COMPOSE_CMD"
        fi
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

# Download package
download_package() {
    local version="$1"
    local download_url="$2"
    
    msg_info "Downloading version: ${version}" >&2
    log_silent "Download URL: $download_url"
    
    mkdir -p "$TEMP_DOWNLOAD_DIR"
    local tarball_name=$(basename "$download_url")
    local tarball_path="${TEMP_DOWNLOAD_DIR}/${tarball_name}"
    
    # Download with proper error handling (disable set -e temporarily)
    msg_info "Downloading from: $download_url" >&2
    set +e
    curl -# -L -f -o "$tarball_path" "$download_url" >&2
    local curl_exit=$?
    set -e
    
    if [[ $curl_exit -ne 0 ]]; then
        msg_error "Download failed from: $download_url" >&2
        msg_error "Check URL accessibility and internet connection" >&2
        msg_error "Curl exit code: $curl_exit" >&2
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
    log_silent "Verified package structure (setup.sh, bitoarch, scripts/lib exist)"
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
    
    log_silent "Checking for new configuration options in newer version..."
    
    local new_keys_added=0
    local temp_additions=$(mktemp)
    
    # Read default env file line by line
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Extract key from KEY=VALUE format
        if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)= ]]; then
            local key="${BASH_REMATCH[1]}"
            
            # Check if this key already exists in the user's env file
            if ! grep -q "^${key}=" "$env_file" 2>/dev/null; then
                # Key doesn't exist - add it with default value
                echo "$line" >> "$temp_additions"
                new_keys_added=$((new_keys_added + 1))
                log_silent "New config key found: $key"
            fi
        fi
    done < "$default_env_file"
    
    # If new keys were found, append them to the env file
    if [[ $new_keys_added -gt 0 ]]; then
        echo "" >> "$env_file"
        echo "# ============================================================================" >> "$env_file"
        echo "# NEW CONFIGURATION OPTIONS (added during upgrade from version ${CURRENT_VERSION:-unknown})" >> "$env_file"
        echo "# Added on: $(date)" >> "$env_file"
        echo "# ============================================================================" >> "$env_file"
        cat "$temp_additions" >> "$env_file"
        
        log_silent "Merged $new_keys_added new config keys from default to env file"
    else
        log_silent "No new config keys to merge - env file is up to date"
    fi
    
    rm -f "$temp_additions"
    return 0
}

# Patch env file with IMAGE variables from new version
patch_env_with_images() {
    local env_file="$1"
    local versions_file="${NEW_DIR}/versions/service-versions.json"
    
    # Check if IMAGE variables already exist
    local images_exist=false
    if grep -q "CIS_CONFIG_IMAGE=" "$env_file" 2>/dev/null; then
        images_exist=true
        log_silent "Updating IMAGE variables to new version..."
    else
        log_silent "Adding IMAGE variables from new version..."
    fi
    
    # Read versions and image bases from NEW version's versions/service-versions.json
    local cis_config_version cis_config_image_base
    local cis_manager_version cis_manager_image_base
    local cis_provider_version cis_provider_image_base
    local cis_tracker_version cis_tracker_image_base
    local mysql_version mysql_image_base
    
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
    fi
    
    # Add or update IMAGE variables
    if [ "$images_exist" = true ]; then
        # Update existing IMAGE variables
        sed -i.bak "s|^CIS_CONFIG_IMAGE=.*|CIS_CONFIG_IMAGE=${cis_config_image_base}:${cis_config_version}|" "$env_file"
        sed -i.bak "s|^CIS_MANAGER_IMAGE=.*|CIS_MANAGER_IMAGE=${cis_manager_image_base}:${cis_manager_version}|" "$env_file"
        sed -i.bak "s|^CIS_PROVIDER_IMAGE=.*|CIS_PROVIDER_IMAGE=${cis_provider_image_base}:${cis_provider_version}|" "$env_file"
        sed -i.bak "s|^CIS_TRACKER_IMAGE=.*|CIS_TRACKER_IMAGE=${cis_tracker_image_base}:${cis_tracker_version}|" "$env_file"
        sed -i.bak "s|^MYSQL_IMAGE=.*|MYSQL_IMAGE=${mysql_image_base}:${mysql_version}|" "$env_file"
    else
        # Append IMAGE variables to env file
        cat >> "$env_file" << EOF

# Image variables (added during upgrade for compatibility with new version)
CIS_CONFIG_IMAGE=${cis_config_image_base}:${cis_config_version}
CIS_MANAGER_IMAGE=${cis_manager_image_base}:${cis_manager_version}
CIS_PROVIDER_IMAGE=${cis_provider_image_base}:${cis_provider_version}
CIS_TRACKER_IMAGE=${cis_tracker_image_base}:${cis_tracker_version}
MYSQL_IMAGE=${mysql_image_base}:${mysql_version}
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
    
    log_silent "Env file patched with IMAGE variables from new version"
    log_silent "Added IMAGE variables from new version: config=${cis_config_version}, manager=${cis_manager_version}, provider=${cis_provider_version}, tracker=${cis_tracker_version}, mysql=${mysql_version}"
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
        # Regular file in OLD_DIR (1.3.x or older) - use OLD_DIR
        config_source="$OLD_DIR"
        log_silent "Using config from OLD_DIR (regular file - 1.3.x installation)"
    elif [[ -f "/usr/local/etc/bitoarch/.env-bitoarch" ]]; then
        # 1.4.x+ installation with configs in /usr/local
        config_source="/usr/local/etc/bitoarch"
        log_silent "Using config from /usr/local/etc/bitoarch (1.4.x+ installation)"
    elif [[ -f "${HOME}/.local/bitoarch/etc/.env-bitoarch" ]]; then
        # 1.4.x+ installation with configs in ~/.local
        config_source="${HOME}/.local/bitoarch/etc"
        log_silent "Using config from ~/.local/bitoarch/etc (1.4.x+ installation)"
    elif [[ -L "${OLD_DIR}/.env-bitoarch" ]] && [[ -f "${OLD_DIR}/.env-bitoarch" ]]; then
        # Symlink in OLD_DIR that points to valid file - follow it
        config_source="$OLD_DIR"
        log_silent "Using config from OLD_DIR (symlink - 1.4.x+ installation)"
    fi
    
    log_silent "Config source: $config_source"
    
    # Copy env files from detected source
    [[ -f "${config_source}/.env-bitoarch" ]] && cp "${config_source}/.env-bitoarch" "${NEW_DIR}/.env-bitoarch"
    [[ -f "${config_source}/.env-llm-bitoarch" ]] && cp "${config_source}/.env-llm-bitoarch" "${NEW_DIR}/.env-llm-bitoarch"

    # Copy repo config
    if [[ -f "${config_source}/.bitoarch-config.yaml" ]]; then
        cp "${config_source}/.bitoarch-config.yaml" "${NEW_DIR}/.bitoarch-config.yaml"
    fi
    
    # Copy or create deployment type marker
    if [[ -f "${config_source}/.deployment-type" ]]; then
        cp "${config_source}/.deployment-type" "${NEW_DIR}/.deployment-type"
        msg_info "Deployment type preserved: $(cat "${NEW_DIR}/.deployment-type")"
        log_silent "Copied .deployment-type from $config_source"
    else
        # Old version without k8s support - default to docker-compose
        echo "docker-compose" > "${NEW_DIR}/.deployment-type"
        msg_info "Setting deployment type to: docker-compose (default for old versions)"
        log_silent "Created .deployment-type with docker-compose for backward compatibility"
    fi
    
    # Merge new config keys from default env file (adds missing keys with default values)
    if [[ -f "$NEW_ENV" ]]; then
        merge_new_env_configs "$NEW_ENV"
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
        log_silent "Extracting latest provider configuration from new package..."
        local docker_config_path="${NEW_DIR}/services/cis-provider/config/default.json"

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
        # Kubernetes: extract latest default.json from image to helm chart path for ConfigMap
        msg_info "Extracting latest provider configuration for Kubernetes deployment..."
        local k8s_config_path="${NEW_DIR}/helm-bitoarch/services/cis-provider/config/default.json"
        
        if [[ -f "$NEW_ENV" ]]; then
            source "$NEW_ENV"
            local provider_image="${CIS_PROVIDER_IMAGE:-}"
            
            if [[ -n "$provider_image" ]]; then
                if docker pull "$provider_image" >> "$LOG_FILE" 2>&1; then
                    if docker create --name temp-provider-config-k8s-upgrade "$provider_image" >/dev/null 2>&1; then
                        if docker cp temp-provider-config-k8s-upgrade:/opt/bito/xmcp/config/default.json "$k8s_config_path" 2>> "$LOG_FILE"; then
                            chmod 666 "$k8s_config_path" 2>/dev/null || true
                            log_silent "Provider configuration extracted from new image for Kubernetes"
                            log_silent "Extracted default.json to: $k8s_config_path"
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
    log_silent "Checking for existing data volumes..." >&2
    
    # Try multiple methods to find volumes
    local volumes_found=0
    local found_project_name=""
    
    # Method 1: Search for volumes matching common patterns
    local all_volumes=$(docker volume ls --format "{{.Name}}" 2>/dev/null)
    
    # Look for volumes with the standard suffixes
    for suffix in "ai_architect_mysql_data" "ai_architect_data" "ai_architect_backups" "ai_architect_temp"; do
        local matching_vol=$(echo "$all_volumes" | grep -E "_${suffix}$" | head -1)
        if [[ -n "$matching_vol" ]]; then
            volumes_found=$((volumes_found + 1))
            # Extract project name from first match (e.g., "test-old" from "test-old_ai_architect_mysql_data")
            if [[ -z "$found_project_name" ]]; then
                found_project_name=$(echo "$matching_vol" | sed "s/_${suffix}$//")
                log_silent "Detected project name from volume: $found_project_name"
            fi
            log_silent "Found existing volume: $matching_vol"
        fi
    done
    
    if [[ $volumes_found -gt 0 ]]; then
        log_silent "Found $volumes_found existing data volume(s) from project: $found_project_name" >&2
        msg_info "Data will be preserved during the upgrade..." >&2
        echo "$found_project_name"
    else
        msg_warn "No existing data volumes found - fresh volumes will be created" >&2
        echo ""
    fi
}

# Configure shared volumes
configure_volumes() {
    log_silent "Configuring shared data volumes..."
    
    local compose_file="${NEW_DIR}/docker-compose.yml"
    local old_volumes_project=$(check_old_volumes)
    
    # Backup original
    cp "$compose_file" "${compose_file}.backup"
    
    # Use awk to remove old volumes section and add new one
    awk '
        /^volumes:/ { in_volumes=1; next }
        in_volumes && /^[a-z]/ { in_volumes=0 }
        !in_volumes { print }
    ' "$compose_file" > "${compose_file}.tmp"
    
    # Configure volumes based on whether old volumes exist
    if [[ -n "$old_volumes_project" ]]; then
        log_silent "Configuring to use existing data volumes (data will be preserved)"
        # Append external volumes to reference existing ones
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
EOF
        log_silent "Volume configuration updated to use external volumes from: $old_volumes_project"
    else
        msg_warn "⚠️  IMPORTANT: No existing data volumes found"
        msg_warn "   Fresh volumes will be created for this installation"
        msg_warn "   If this is unexpected, please verify your old installation had running services"
        # Append local volumes (docker will create fresh ones)
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
EOF
        log_silent "Volume configuration updated to use fresh local volumes"
    fi
    
    mv "${compose_file}.tmp" "$compose_file"
    log_silent "Volume configuration complete"
}

# Start new version using setup.sh --from-existing-config
start_new_version() {
    msg_info "Starting new version..."
    
    cd "$NEW_DIR" || exit 1
    
    configure_volumes
    
    # CRITICAL: Sync migrated configs to standard location BEFORE running setup.sh
    # This ensures setup.sh reads the correct (old) credentials
    # shellcheck disable=SC1090
    source "${NEW_DIR}/scripts/lib/path-manager.sh"
    init_paths

    local standard_config_dir="$(get_config_dir)"
    log_silent "Syncing migrated configs to standard location: $standard_config_dir"
    mkdir -p "$standard_config_dir"

    # Copy all config files from NEW_DIR (which has old installation's configs)
    for config_file in .env-bitoarch .env-llm-bitoarch .bitoarch-config.yaml .deployment-type; do
        if [[ -f "${NEW_DIR}/${config_file}" ]]; then
            cp "${NEW_DIR}/${config_file}" "$standard_config_dir/${config_file}"
            log_silent "Synced ${config_file} to $standard_config_dir"
        fi
    done

    log_silent "All configs synced to standard location with correct credentials"

    log_silent "Running: ./setup.sh --from-existing-config"
    msg_info "This may take 2-5 minutes (starting containers)..."
    
    # Run setup.sh in background and show progress
    ./setup.sh --from-existing-config > "$LOG_FILE" 2>&1 &
    local setup_pid=$!
    
    # Show progress dots while setup.sh is running
    while kill -0 $setup_pid 2>/dev/null; do
        echo -n "."
        sleep 2
    done
    echo ""
    
    # Check exit status (disable set -e temporarily)
    set +e
    wait $setup_pid
    local exit_code=$?
    set -e
    
    if [ $exit_code -eq 0 ]; then
        msg_success "New version started"
    else
        msg_error "Failed to start new version (exit code: $exit_code)"
        msg_error "Check log file for details: $LOG_FILE"
        echo ""
        tail -30 "$LOG_FILE"
        echo ""
        exit 1
    fi
}

# Start new version - STANDALONE MODE (direct docker compose)
start_new_version_standalone() {
    msg_info "Starting new version (standalone mode)..."
    
    cd "$NEW_DIR" || exit 1
    configure_volumes
    
    msg_info "Cleaning up old containers..."
    docker ps -a --filter "name=ai-architect" --format "{{.Names}}" | xargs -r docker rm -f >> "$LOG_FILE" 2>&1 || true
    
    msg_info "Cleaning up old networks..."
    docker network ls --format "{{.Name}}" | grep "ai-architect-network" | xargs -r docker network rm >> "$LOG_FILE" 2>&1 || true
    
    msg_info "Starting new services..."
    msg_info "This may take 2-5 minutes (pulling images, starting containers)..."
    
    if [[ "$DOCKER_COMPOSE_CMD" == "docker compose" ]]; then
        docker compose --env-file "$ENV_FILE" up -d --pull always > "$LOG_FILE" 2>&1 &
    else
        # For docker-compose v1, use --env-file flag (requires docker-compose 1.25.0+)
        # Fallback to sourcing if very old version
        if $DOCKER_COMPOSE_CMD --help | grep -q "\-\-env-file"; then
            $DOCKER_COMPOSE_CMD --env-file "$ENV_FILE" pull >> "$LOG_FILE" 2>&1 || true
            $DOCKER_COMPOSE_CMD --env-file "$ENV_FILE" up -d > "$LOG_FILE" 2>&1 &
        else
            # Legacy fallback: source the file
            set -a
            source "$ENV_FILE"
            set +a
            $DOCKER_COMPOSE_CMD pull >> "$LOG_FILE" 2>&1 || true
            $DOCKER_COMPOSE_CMD up -d > "$LOG_FILE" 2>&1 &
        fi
    fi
    
    local compose_pid=$!
    
    while kill -0 $compose_pid 2>/dev/null; do
        echo -n "."
        sleep 2
    done
    echo ""
    
    set +e
    wait $compose_pid
    local exit_code=$?
    set -e
    
    if [ $exit_code -eq 0 ]; then
        msg_success "New version started"
    else
        msg_error "Failed to start new version (exit code: $exit_code)"
        msg_error "Check log file for details: $LOG_FILE"
        echo ""
        tail -30 "$LOG_FILE"
        echo ""
        exit 1
    fi
}

# Wait for services
wait_for_services() {
    msg_info "Deploying AI Architect with latest version..."
    sleep 10
    msg_success "AI Architect deployed"
}

# Check service status
check_services() {
    msg_info "Verifying AI Architect services..."
    
    cd "$NEW_DIR" || exit 1
    
    local running_count=$(docker ps --filter "name=ai-architect" --filter "status=running" --format "{{.Names}}" 2>/dev/null | wc -l | tr -d ' ')
    
    if [[ "$running_count" -gt 0 ]]; then
        msg_success "Found $running_count service(s) running"
        echo ""
        docker ps --filter "name=ai-architect" --format "table {{.Names}}\t{{.Status}}" 2>/dev/null | head -11
        echo ""
    else
        msg_warn "No services appear to be running yet - they may still be starting"
        msg_info "Check status with: cd ${NEW_DIR} && ./setup.sh --status"
    fi
}

# Check if old services are running
check_old_services_running() {
    log_silent "Checking old installation services..."
    
    cd "$OLD_DIR" || return 1
    
    # Count running containers with ai-architect in name
    local running_count=$(docker ps --filter "name=ai-architect" --format "{{.Names}}" 2>/dev/null | wc -l | tr -d ' ')
    
    if [[ "$running_count" -gt 0 ]]; then
        log_silent "Found $running_count running service(s) in old installation"
        return 0
    else
        msg_warn "No services running in old installation"
        return 1
    fi
}

# Stop old version using setup.sh --stop (EMBEDDED MODE)
stop_old_version() {
    log_silent "Checking old installation status..."
    
    if ! check_old_services_running; then
        msg_warn "⚠️  Old installation services are not running"
        msg_warn "   Skipping stop operation (nothing to stop)"
        log_silent "Skipped stopping old version - no services running"
        return 0
    fi
    
    log_silent "Stopping old version services..."
    
    cd "$OLD_DIR" || exit 1
    
    log_silent "Running: ./setup.sh --stop"
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
        msg_info "Stopping old containers..."
        log_silent "Containers to stop: $old_containers"
        echo "$old_containers" | xargs -r docker stop >> "$LOG_FILE" 2>&1
        msg_success "Old version stopped"
    else
        msg_warn "No old containers found to stop"
        msg_info "This is expected if services were already stopped"
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
    
    log_silent "Syncing migrated configs to standard location: $standard_config_dir"
    mkdir -p "$standard_config_dir"

    # Copy all config files from NEW_DIR (which has patched configs from migrate_config)
    # Then remove them from NEW_DIR since K8s doesn't need local config files
    for config_file in .env-bitoarch .env-llm-bitoarch .bitoarch-config.yaml .deployment-type; do
        if [[ -f "${NEW_DIR}/${config_file}" ]]; then
            if [[ "${NEW_DIR}" != "${standard_config_dir}" ]]; then
                cp "${NEW_DIR}/${config_file}" "$standard_config_dir/${config_file}"
                # Remove from NEW_DIR - K8s doesn't need config files in installation directory
                rm -f "${NEW_DIR}/${config_file}"
                log_silent "Synced ${config_file} to $standard_config_dir and removed from NEW_DIR"
            else
                log_silent "Skipped ${config_file} (source=destination)"
            fi
        fi
    done

    msg_success "All configs synced to standard location (removed from installation dir)"

    # Update bitoarch CLI symlink to point to new installation
    # CRITICAL: Must use scripts/bitoarch.sh, NOT the root bitoarch file
    # The root bitoarch expects lib/ at root level, but files are at scripts/lib/
    # The scripts/bitoarch.sh correctly resolves lib/ relative to scripts/ directory
    msg_info "Updating bitoarch CLI symlink..."
    local cli_bin_dir="$HOME/.local/bin"
    local cli_target="$cli_bin_dir/bitoarch"
    local cli_source="${NEW_DIR}/scripts/bitoarch.sh"

    if [[ -f "$cli_source" ]]; then
        mkdir -p "$cli_bin_dir"
        chmod +x "$cli_source"
        ln -sf "$cli_source" "$cli_target"
        msg_success "Updated bitoarch symlink: $cli_target -> $cli_source"
        log_silent "Updated bitoarch CLI symlink to new installation"
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

        # Force rollout restart to ensure pods pull latest images with imagePullPolicy=Always
        # Critical when upgrading to same version but with updated images in registry
        kubectl rollout restart deployment -n "$namespace" -l "app.kubernetes.io/name=bitoarch" >> "$LOG_FILE" 2>&1 || true

        log_silent "Pod rollout initiated to force image pull"

        # CRITICAL: Wait for ALL rollouts to complete before starting port-forwards
        # This prevents race condition where port-forward connects to terminating pod
        msg_info "Waiting for all deployment rollouts to complete..."
        for component in provider manager config tracker mysql; do
            msg_info "  Waiting for ai-architect-${component} rollout..."
            if kubectl rollout status deployment/ai-architect-${component} -n "$namespace" --timeout=180s >> "$LOG_FILE" 2>&1; then
                log_silent "Rollout complete: ai-architect-${component}"
            else
                msg_warn "  Rollout may not have completed for ai-architect-${component}"
            fi
        done
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
    
    log_silent "Kubernetes upgrade completed successfully"

    # CRITICAL: Wait for pods to be ready after rollout restart
    # Inline implementation to work regardless of kubernetes-manager.sh version
    msg_info "Waiting for pods to be ready after rollout restart..."
    local max_wait=180
    local waited=0
    local services=("mysql" "config" "manager" "provider" "tracker")

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

    local provider_int="${XMCP_HTTP_PORT:-8080}"
    local manager_int="${CIS_MANAGER_PORT:-9090}"
    local config_int="${CIS_CONFIG_PORT:-8081}"
    local mysql_int="${MYSQL_PORT:-3306}"
    local tracker_int="${CIS_TRACKING_PORT:-9920}"

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
    sleep 2

    # Verify and retry port-forwards with health check
    local max_verify_attempts=3
    local verify_attempt=1

    while [ $verify_attempt -le $max_verify_attempts ]; do
        local pf_count=$(ps aux | grep "kubectl port-forward" | grep -E "(-n |--namespace=|-n=)$namespace" | grep -v grep | wc -l | xargs)

        if [ "$pf_count" -ge 5 ]; then
            msg_success "Port-forwards established (5/5 services)"
            break
        fi

        msg_warn "Only $pf_count/5 port-forwards running (attempt $verify_attempt)"

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

        sleep 2
        verify_attempt=$((verify_attempt + 1))
    done

    # Final health check - test actual connectivity
    msg_info "Verifying port-forward connectivity..."
    local health_ok=true

    for port in $provider_ext $manager_ext $config_ext $tracker_ext; do
        if ! curl -s --connect-timeout 2 "http://localhost:$port/health" >/dev/null 2>&1; then
            health_ok=false
            log_silent "Port $port health check failed"
        fi
    done

    if [ "$health_ok" = true ]; then
        msg_success "All port-forwards healthy and responding"
    else
        msg_warn "Some port-forwards may not be healthy"
        msg_info "If port-forwards die, restart with: cd ${NEW_DIR} && ./setup.sh --restart"
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
    kubectl get pods -n "$namespace" 2>/dev/null | head -11
    echo ""
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
    
    # Run migrations
    if run_upgrade_migrations; then
        log_silent "Database migrations completed"
    else
        msg_error "Database migrations failed"
        return 1
    fi
    
    return 0
}

# Print Kubernetes success summary
print_kubernetes_success() {
    print_header "✅ KUBERNETES UPGRADE COMPLETE"
    
    echo -e "${GREEN}✓ Upgrade successful!${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANT: Update your PATH to use the new installation:${NC}"
    echo ""
    echo -e "   ${BLUE}cd ${NEW_DIR}${NC}"
    echo ""
    echo -e "${YELLOW}Verify Upgrade:${NC}"
    echo -e "   ${BLUE}bitoarch status${NC}"
    echo -e "   ${BLUE}bitoarch index-status${NC}"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📋 Upgrade Log${NC}"
    echo -e "   ${LOG_FILE}"
    echo ""
    echo -e "${BLUE}🧹 Cleanup Old Installation (after verifying new version)${NC}"
    echo -e "   ${YELLOW}rm -rf ${OLD_DIR}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Cleanup temporary files
cleanup() {
    [[ -d "$TEMP_DOWNLOAD_DIR" ]] && rm -rf "$TEMP_DOWNLOAD_DIR"
}

trap cleanup EXIT

# Print success summary
print_success() {
    print_header "✅ UPGRADE COMPLETE"
    
    echo -e "${GREEN}✓ Upgrade successful!${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANT: Change to the new installation directory:${NC}"
    echo ""
    echo -e "   ${BLUE}cd ${NEW_DIR}${NC}"
    echo ""
    echo -e "${YELLOW}Then verify the installation:${NC}"
    echo -e "   ${BLUE}bitoarch status${NC}"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "⚠️  After a successful upgrade, rollback is not supported"
    echo ""
    echo -e "${BLUE}📋 Upgrade Log${NC}"
    echo -e "   ${LOG_FILE}"
    echo ""
    echo -e "${BLUE}🧹 Cleanup Old Installation (after verifying new version)${NC}"
    echo -e "   ${YELLOW}rm -rf ${OLD_DIR}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Main execution
main() {
    print_header "🔄 BITO's AI Architect Upgrade"
    
    parse_args "$@"
    
    log_silent "=== Upgrade Started ==="
    log_silent "OLD_DIR: ${OLD_DIR}"
    log_silent "Target version: ${TARGET_VERSION}"
    log_silent "Custom URL: ${CUSTOM_URL:-none}"
    
    # Pre-flight checks
    check_prerequisites
    verify_old_installation
    
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
    
    # Configure and deploy based on mode
    migrate_config
    
    if [[ "$UPGRADE_MODE" == "kubernetes" ]]; then
        # Kubernetes mode: Helm upgrade with rolling update
        upgrade_kubernetes
        check_kubernetes_services
        run_database_migrations
        print_kubernetes_success
    elif [[ "$UPGRADE_MODE" == "standalone" ]]; then
        # Standalone mode: stop old, start new, verify
        stop_old_version_standalone
        start_new_version_standalone
        wait_for_services
        check_services
        run_database_migrations
        print_success
    else
        # Embedded mode: start new, verify, stop old
        start_new_version
        wait_for_services
        check_services
        run_database_migrations
        stop_old_version
        print_success
    fi
    
    log_silent "=== Upgrade Completed Successfully ==="
    log_silent "New installation: $NEW_DIR"
}

main "$@"
