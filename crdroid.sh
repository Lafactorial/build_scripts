#!/bin/bash

set -e

# ============================================================
# Garnet Build Script
# ============================================================

# -----------------------------
# ROM Configuration
# -----------------------------
ROM_NAME="crDroid"
ROM_URL="https://github.com/crdroidandroid/android"
ROM_BRANCH="16.0"

MANIFEST_URL="https://github.com/Lafactorial/local_manifest.git"
MANIFEST_BRANCH="garnet-crdroid"

DEVICE="garnet"

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

JOB_START=$(date +%s)

# ============================================================
# UI
# ============================================================

banner() {
    clear

    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║                                                            ║"
    echo "║                  crDroidandroid                            ║"
    echo "║               Automated Build Script                       ║"
    echo "║                                                            ║"
    echo "╠════════════════════════════════════════════════════════════╣"
    echo "║  Device     : POCO X6 5G / garnet                          ║"
    echo "║  Branch     : 16.0                                         ║"
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

ok "Workspace prepared"

# ============================================================
# Repo Init
# ============================================================

section "Initializing crDroid Source"

repo init \
    -u "${ROM_URL}" \
    -b "${ROM_BRANCH}" \
    --git-lfs \
    --no-clone-bundle \
    --depth=1

ok "crDroid repository initialized"

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
# Install Clean
# ============================================================

section "Running Install Clean"

make installclean

ok "Install clean complete"

# ============================================================
# Build
# ============================================================

section "Building crDroid"

BUILD_START=$(date +%s)

info "Executing brunch for target: ${DEVICE}"

if brunch "${DEVICE}"; then

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

    fail "crDroid build failed"
    info "Build time: ${BUILD_MINUTES} minutes"

    exit 1

fi

# ============================================================
# Build Successful
# ============================================================

ok "crDroid build successful"
info "Build time: ${BUILD_MINUTES} minutes"

# ============================================================
# Gofile Upload
# ============================================================

section "Uploading to Gofile"

OUT_PATH="out/target/product/${DEVICE}"
ZIP_FILE=$(find "${OUT_PATH}" -maxdepth 1 -type f -iname "crDroid*.zip" | head -n 1)

if [[ -f "${ZIP_FILE}" ]]; then
    info "Found build file: ${ZIP_FILE}"
    info "Uploading to Gofile (new API)..."

    UPLOAD_RESP=$(curl -s -F "file=@${ZIP_FILE}" "https://upload.gofile.io/uploadfile")

    STATUS=$(echo "${UPLOAD_RESP}" | jq -r '.status' 2>/dev/null || true)
    DOWNLOAD_PAGE=$(echo "${UPLOAD_RESP}" | jq -r '.data.downloadPage' 2>/dev/null || true)

    if [[ "${STATUS}" == "ok" && -n "${DOWNLOAD_PAGE}" && "${DOWNLOAD_PAGE}" != "null" ]]; then
        ok "File successfully uploaded!"
        GOFILE_LINK="${DOWNLOAD_PAGE}"
    else
        fail "Failed to upload file to Gofile."
        echo "Response:"
        echo "${UPLOAD_RESP}" | jq . 2>/dev/null || echo "${UPLOAD_RESP}"
        GOFILE_LINK="Upload Failed"
    fi
else
    fail "No zip file found in ${OUT_PATH} matching 'crDroid*.zip'"
    GOFILE_LINK="File Not Found"
fi

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
echo "║                  CRDROID BUILD COMPLETED                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

if [[ "${GOFILE_LINK}" == http* ]]; then
    echo -e "${YELLOW}${BOLD} Download Link: ${CYAN}${GOFILE_LINK}${RESET}\n"
else
    echo -e "${RED}${BOLD} Download Link Status: ${GOFILE_LINK}${RESET}\n"
fi
