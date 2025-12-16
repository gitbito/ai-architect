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
UPGRADE_MODE=""  # Will be set to "embedded" or "standalone"
CURRENT_VERSION=""
DOCKER_COMPOSE_CMD=""

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
    
    # Detect current version and determine upgrade mode
    detect_current_version "$OLD_DIR"
    
    if [[ "$CURRENT_VERSION" == "1.0.0" ]]; then
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
    
    # Check Docker
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
    
    msg_success "System requirements verified"
}

# Verify old installation
verify_old_installation() {
    msg_info "Verifying existing installation..."
    
    if [[ ! -d "$OLD_DIR" ]]; then
        msg_error "Old installation not found: $OLD_DIR"
        exit 1
    fi
    
    if [[ ! -f "$OLD_ENV" ]]; then
        msg_error "Configuration not found: $OLD_ENV"
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

# Migrate configuration
migrate_config() {
    msg_info "Migrating configuration..."
    
    NEW_ENV="${NEW_DIR}/.env-bitoarch"
    
    # Copy env files
    [[ -f "${OLD_DIR}/.env-bitoarch" ]] && cp "${OLD_DIR}/.env-bitoarch" "${NEW_DIR}/.env-bitoarch"
    [[ -f "${OLD_DIR}/.env-llm-bitoarch" ]] && cp "${OLD_DIR}/.env-llm-bitoarch" "${NEW_DIR}/.env-llm-bitoarch"
    [[ -f "${OLD_DIR}/.bitoarch-config.yaml" ]] && cp "${OLD_DIR}/.bitoarch-config.yaml" "${NEW_DIR}/.bitoarch-config.yaml"
    
    msg_success "Configuration migrated"
}

# Check if docker volumes exist from old installation
check_old_volumes() {
    msg_info "Checking for existing data volumes..." >&2
    
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
        msg_success "Found $volumes_found existing data volume(s) from project: $found_project_name" >&2
        msg_info "Data will be preserved and shared with new installation" >&2
        echo "$found_project_name"
    else
        msg_warn "No existing data volumes found - fresh volumes will be created" >&2
        echo ""
    fi
}

# Configure shared volumes
configure_volumes() {
    msg_info "Configuring shared data volumes..."
    
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
        msg_info "Configuring to use existing data volumes (data will be preserved)"
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
    msg_success "Volume configuration complete"
}

# Start new version using setup.sh --from-existing-config
start_new_version() {
    msg_info "Starting new version..."
    
    cd "$NEW_DIR" || exit 1
    
    configure_volumes
    
    msg_info "Running: ./setup.sh --from-existing-config"
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
        docker compose --env-file .env-bitoarch up -d > "$LOG_FILE" 2>&1 &
    else
        set -a
        source .env-bitoarch
        set +a
        $DOCKER_COMPOSE_CMD up -d > "$LOG_FILE" 2>&1 &
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
    msg_info "Allowing new services to initialize (10 seconds)..."
    sleep 10
    msg_success "Initialization period complete"
}

# Check service status
check_services() {
    msg_info "Verifying new services..."
    
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
    msg_info "Checking old installation services..."
    
    cd "$OLD_DIR" || return 1
    
    # Count running containers with ai-architect in name
    local running_count=$(docker ps --filter "name=ai-architect" --format "{{.Names}}" 2>/dev/null | wc -l | tr -d ' ')
    
    if [[ "$running_count" -gt 0 ]]; then
        msg_info "Found $running_count running service(s) in old installation"
        return 0
    else
        msg_warn "No services running in old installation"
        return 1
    fi
}

# Stop old version using setup.sh --stop (EMBEDDED MODE)
stop_old_version() {
    msg_info "Checking old installation status..."
    
    if ! check_old_services_running; then
        msg_warn "⚠️  Old installation services are not running"
        msg_warn "   Skipping stop operation (nothing to stop)"
        log_silent "Skipped stopping old version - no services running"
        return 0
    fi
    
    msg_info "Stopping old version services..."
    
    cd "$OLD_DIR" || exit 1
    
    msg_info "Running: ./setup.sh --stop"
    if ./setup.sh --stop 2>&1 | tee -a "$LOG_FILE" | tail -10; then
        msg_success "Old version stopped"
    else
        msg_warn "Some issues stopping old version"
    fi
}

# Stop old version - STANDALONE MODE (direct docker commands)
stop_old_version_standalone() {
    msg_info "Stopping old version services..."
    
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
            download_url="${DOWNLOAD_BASE_URL}/versions/${TARGET_VERSION}/bito-ai-architect-${TARGET_VERSION}.tar.gz"
        fi
        tarball_path=$(download_package "$version_name" "$download_url")
    fi
    
    extract_package "$tarball_path" "$version_name"
    
    # Configure and deploy based on mode
    migrate_config
    
    if [[ "$UPGRADE_MODE" == "standalone" ]]; then
        # Standalone mode: stop old, start new, verify
        stop_old_version_standalone
        start_new_version_standalone
        wait_for_services
    else
        # Embedded mode: start new, verify, stop old
        start_new_version
        wait_for_services
        check_services
        stop_old_version
    fi
    
    check_services
    
    # Success
    print_success
    
    log_silent "=== Upgrade Completed Successfully ==="
    log_silent "New installation: $NEW_DIR"
}

main "$@"
