#!/bin/bash

set -e

# ============================================================
# Evolution-X Garnet Build Script
# ============================================================

# -----------------------------
# ROM Configuration
# -----------------------------
ROM_NAME="Evolution-X"
ROM_URL="https://github.com/Evolution-X/manifest"
ROM_BRANCH="cnb"

MANIFEST_URL="https://github.com/Lafactorial/local_manifest.git"
MANIFEST_BRANCH="garnet-evo"

DEVICE="garnet"
LUNCH_TARGET="lineage_garnet-cp2a-user"

export TZ="Europe/Istanbul"
export BUILD_USERNAME="HaKaN"
export BUILD_HOSTNAME="crave"

# -----------------------------
# Colors
# -----------------------------
RESET='\033[0m'
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
BOLD='\033[1m'

section() {
    echo
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
    printf "${CYAN}${BOLD}║  %-56s║${RESET}\n" "$1"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"
}

info() {
    echo -e "${BLUE}ℹ ${RESET}$1"
}

ok() {
    echo -e "${GREEN}✔ ${RESET}$1"
}

warn() {
    echo -e "${YELLOW}⚠ ${RESET}$1"
}

fail() {
    echo -e "${RED}✖ ${RESET}$1"
}

# -----------------------------
# Runtime variables
# -----------------------------
BUILD_MARKER="out/.garnet_evolution_first_build_done"

JOB_START=$(date +%s)

# ============================================================
# UI
# ============================================================

banner() {
    clear

    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║        ███████╗██╗   ██╗ ██████╗ ██╗  ██╗                ║"
    echo "║        ██╔════╝██║   ██║██╔═══██╗╚██╗██╔╝                ║"
    echo "║        █████╗  ██║   ██║██║   ██║ ╚███╔╝                 ║"
    echo "║        ██╔══╝  ╚██╗ ██╔╝██║   ██║ ██╔██╗                 ║"
    echo "║        ███████╗ ╚████╔╝ ╚██████╔╝██╔╝ ██╗                ║"
    echo "║        ╚══════╝  ╚═══╝   ╚═════╝ ╚═╝  ╚═╝                ║"
    echo "║                                                            ║"
    echo "║              E V O L U T I O N   X                       ║"
    echo "║              Automated Release Builder                    ║"
    echo "║                                                            ║"
    echo "╠════════════════════════════════════════════════════════════╣"
    echo "║  Device     : POCO X6 5G / garnet                         ║"
    echo "║  Build      : cp2a-user                                   ║"
    echo "║  Branch     : cnb                                         ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

# ============================================================
# Start
# ============================================================

banner

section "Checking Dependencies"

command -v git >/dev/null || {
    fail "git is missing"
    exit 1
}

command -v repo >/dev/null || {
    fail "repo is missing"
    exit 1
}

command -v curl >/dev/null || {
    fail "curl is missing"
    exit 1
}

command -v jq >/dev/null || {
    fail "jq is missing"
    exit 1
}


ok "Dependencies ready"

# ============================================================
# Prepare Workspace
# ============================================================

section "Preparing Workspace"

rm -rf .repo/local_manifests
rm -rf "out/target/product/${DEVICE}"
rm -rf prebuilts/gcc 2>/dev/null || true

ok "Workspace prepared"

# ============================================================
# Repo Init
# ============================================================

section "Initializing Evolution-X"

repo init \
    -u "${ROM_URL}" \
    -b "${ROM_BRANCH}" \
    --git-lfs \
    --depth=1

ok "Evolution-X repository initialized"

# ============================================================
# Local Manifest
# ============================================================

section "Cloning Device Manifest"

git clone \
    --depth=1 \
    "${MANIFEST_URL}" \
    -b "${MANIFEST_BRANCH}" \
    .repo/local_manifests

ok "Device manifest installed"

# ============================================================
# Sync
# ============================================================

section "Syncing Source"

SYNC_START=$(date +%s)

if [[ -x "/opt/crave/resync.sh" ]]; then

    info "Using Crave resync"

    if /opt/crave/resync.sh; then

        ok "Crave resync complete"

    else

        warn "Crave resync returned an error"
        warn "Starting forced repo sync..."

        repo sync \
            -c \
            --force-sync \
            --force-remove-dirty \
            --no-tags \
            --no-clone-bundle \
            || {
                warn "Forced repo sync returned an error"
                warn "Continuing build anyway..."
            }

    fi

else

    warn "Crave resync not found"
    info "Using forced repo sync"

    repo sync \
        -c \
        --force-sync \
        --force-remove-dirty \
        --no-tags \
        --no-clone-bundle \
        || {
            warn "Repo sync returned an error"
            warn "Continuing build anyway..."
        }

fi

SYNC_END=$(date +%s)

ok "Source sync stage finished"
info "Sync time: $(((SYNC_END - SYNC_START) / 60)) minutes"

# ============================================================
# Build Environment
# ============================================================

section "Loading Build Environment"

. build/envsetup.sh

ok "Build environment loaded"

# ============================================================
# Lunch
# ============================================================

section "Build Configuration"

echo -e "${CYAN}${BOLD}"
echo "╭────────────────────────────────────────────────────────────╮"
echo "│ TARGET                                                     │"
echo "├────────────────────────────────────────────────────────────┤"
echo "│ Device     : POCO X6 5G/ garnet                           │"
echo "│ Product    : lineage_garnet                               │"
echo "│ Variant    : cp2a-user                                    │"
echo "│ Build type : User                                         │"
echo "╰────────────────────────────────────────────────────────────╯"
echo -e "${RESET}"

info "Selecting target: ${LUNCH_TARGET}"

lunch "${LUNCH_TARGET}"

ok "Build target selected: ${LUNCH_TARGET}"

# ============================================================
# Install Clean
# ============================================================

section "Running Install Clean"

make installclean

ok "Install clean complete"

# ============================================================
# Build
# ============================================================

section "Building Evolution-X"

BUILD_START=$(date +%s)

if m evolution; then

    BUILD_SUCCESS=1

else

    BUILD_SUCCESS=0

fi

BUILD_END=$(date +%s)
BUILD_MINUTES=$(((BUILD_END - BUILD_START) / 60))

# ============================================================
# Build Failed
# ============================================================

if [[ "${BUILD_SUCCESS}" != "1" ]]; then

    fail "Evolution-X build failed"
    info "Build time: ${BUILD_MINUTES} minutes"

    exit 1

fi

# ============================================================
# Build Successful
# ============================================================

ok "Evolution-X build successful"
info "Build time: ${BUILD_MINUTES} minutes"

mkdir -p "$(dirname "${BUILD_MARKER}")"
touch "${BUILD_MARKER}"
ok "Successful build marker updated"

# ============================================================
# Finish
# ============================================================

JOB_END=$(date +%s)
TOTAL_MINUTES=$(((JOB_END - JOB_START) / 60))

section "Job Complete"

ok "Everything finished"
info "Total time: ${TOTAL_MINUTES} minutes"

echo

echo -e "${GREEN}${BOLD}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                  EVOLUTION-X COMPLETE                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"
