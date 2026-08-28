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

DEVICE="garnet-evo"
BUILD_VARIANT="cp2a-user"
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

# -----------------------------
# Runtime variables
# -----------------------------
PIXELDRAIN_URL=""
GOFILE_URL=""
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
    echo "║  Device     : POCO x6 5G / peridot                         ║"
    echo "║  Build      : cp2a-user                                   ║"
    echo "║  Branch     : cnb                                         ║"
    echo "║  Release    : ZIP only                                    ║"
    echo "║  Upload     : PixelDrain + GoFile                        ║"
    echo "║  Notify     : Telegram                                    ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

description() {
    echo
    echo -e "${CYAN}${BOLD}╭────────────────────────────────────────────────────────────╮${RESET}"
    echo -e "${CYAN}${BOLD}│ ABOUT                                                      │${RESET}"
    echo -e "${CYAN}${BOLD}├────────────────────────────────────────────────────────────┤${RESET}"
    echo -e "${CYAN}│${RESET} Evolution-X automated build and release script for       ${CYAN}│${RESET}"
    echo -e "${CYAN}│${RESET} ${BOLD}POCO X6 5G (garnet)${RESET}.                                    ${CYAN}│${RESET}"
    echo -e "${CYAN}│${RESET}                                                            ${CYAN}│${RESET}"
    echo -e "${CYAN}│${RESET} Source → Sync → Build → Package → Upload → Notify         ${CYAN}│${RESET}"
    echo -e "${CYAN}│${RESET}                                                            ${CYAN}│${RESET}"
    echo -e "${CYAN}│${RESET} The final ROM ZIP is uploaded to PixelDrain and GoFile,   ${CYAN}│${RESET}"
    echo -e "${CYAN}│${RESET} then the download links are sent to Telegram automatically.${CYAN}│${RESET}"
    echo -e "${CYAN}╰────────────────────────────────────────────────────────────╯${RESET}"
    echo
}

# ============================================================
# Optional .env
# ============================================================

if [[ -f ".env" ]]; then
    source ".env"
    ok ".env loaded"
else
    warn ".env not found - continuing"
fi

# ============================================================
# Telegram
# ============================================================

tg_send() {
    local MESSAGE="$1"

    [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]] && return 0
    [[ -z "${TELEGRAM_CHAT_ID:-}" ]] && return 0

    curl -sS \
        -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=${MESSAGE}" \
        >/dev/null 2>&1 || true
}

# ============================================================
# Telegram - Build Started
# ============================================================

notify_build_start() {

    tg_send "🚀 Evolution-X build started

Device: ${DEVICE}
Variant: ${BUILD_VARIANT}
Branch: ${ROM_BRANCH}
Host: ${BUILD_HOSTNAME}
Builder: ${BUILD_USERNAME}

⏳ Build in progress..."
}

# ============================================================
# Telegram - Build Failed
# ============================================================

notify_build_failed() {

    tg_send "❌ Evolution-X build FAILED

Device: ${DEVICE}
Variant: ${BUILD_VARIANT}
Branch: ${ROM_BRANCH}
Host: ${BUILD_HOSTNAME}

⚠️ Check the Crave build output for details."
}

# ============================================================
# Telegram - Artifact
# ============================================================

notify_artifact() {

    local FILE="$1"

    local NAME
    local SIZE

    NAME=$(basename "$FILE")
    SIZE=$(du -h "$FILE" | cut -f1)

    local MESSAGE="📦 Evolution-X

Device: ${DEVICE}
Variant: ${BUILD_VARIANT}

📄 ${NAME}
💾 ${SIZE}"

    # -------------------------------
    # PixelDrain
    # -------------------------------

    if [[ -n "${PIXELDRAIN_URL}" ]]; then

        MESSAGE="${MESSAGE}

🟢 PixelDrain
${PIXELDRAIN_URL}"

    else

        MESSAGE="${MESSAGE}

🔴 PixelDrain
Upload failed/skipped"

    fi

    # -------------------------------
    # GoFile
    # -------------------------------

    if [[ -n "${GOFILE_URL}" ]]; then

        MESSAGE="${MESSAGE}

🟢 GoFile
${GOFILE_URL}"

    else

        MESSAGE="${MESSAGE}

🔴 GoFile
Upload failed/skipped"

    fi

    tg_send "$MESSAGE"
}

# ============================================================
# Telegram - Finished
# ============================================================

notify_finished() {

    local MINUTES="$1"

    tg_send "🏁 Evolution-X build finished

Device: ${DEVICE}
Variant: ${BUILD_VARIANT}

⏱ Total time: ${MINUTES} minutes"
}

# ============================================================
# PixelDrain Upload
# ============================================================

upload_pixeldrain() {

    local FILE="$1"

    PIXELDRAIN_URL=""

    if [[ ! -f "$FILE" ]]; then
        fail "File not found: $FILE"
        return 1
    fi

    if [[ -z "${PIXELDRAIN_TOKEN:-}" ]]; then
        warn "PIXELDRAIN_TOKEN not set"
        return 1
    fi

    section "PixelDrain Upload"

    info "File: $(basename "$FILE")"
    info "Size: $(du -h "$FILE" | cut -f1)"

    local RESPONSE
    local FILE_ID

    RESPONSE=$(curl \
        --progress-bar \
        -T "$FILE" \
        -u ":${PIXELDRAIN_TOKEN}" \
        "https://pixeldrain.com/api/file/" 2>/dev/null)

    FILE_ID=$(echo "$RESPONSE" | jq -r '.id // empty')

    if [[ -z "$FILE_ID" ]]; then

        fail "PixelDrain upload failed"

        echo "$RESPONSE"

        return 1

    fi

    PIXELDRAIN_URL="https://pixeldrain.com/u/${FILE_ID}"

    ok "PixelDrain upload complete"
    info "$PIXELDRAIN_URL"
}

# ============================================================
# GoFile Upload
# ============================================================

upload_gofile() {

    local FILE="$1"

    GOFILE_URL=""

    if [[ ! -f "$FILE" ]]; then
        fail "File not found: $FILE"
        return 1
    fi

    section "GoFile Upload"

    info "File: $(basename "$FILE")"
    info "Size: $(du -h "$FILE" | cut -f1)"

    local RESPONSE
    local DOWNLOAD_URL

    RESPONSE=$(curl \
        --progress-bar \
        -X POST \
        -F "file=@${FILE}" \
        "https://upload-ap-sgp.gofile.io/uploadfile" 2>/dev/null)

    DOWNLOAD_URL=$(echo "$RESPONSE" | jq -r '.data.downloadPage // empty')

    if [[ -z "$DOWNLOAD_URL" ]]; then

        fail "GoFile upload failed"

        echo "$RESPONSE"

        return 1

    fi

    GOFILE_URL="$DOWNLOAD_URL"

    ok "GoFile upload complete"
    info "$GOFILE_URL"
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
rm -rf "device/xiaomi/${DEVICE}"

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
# Load .env Again
# ============================================================

if [[ -f ".env" ]]; then
    source ".env"
fi

# ============================================================
# Lunch
# ============================================================

section "Build Configuration"

echo -e "${CYAN}${BOLD}"
echo "╭────────────────────────────────────────────────────────────╮"
echo "│ TARGET                                                     │"
echo "├────────────────────────────────────────────────────────────┤"
echo "│ Device     : POCO X6 5G / garnet                          │"
echo "│ Product    : lineage_garnet                               │"
echo "│ Variant    : cp2a-user                                    │"
echo "│ Build type : User                                         │"
echo "╰────────────────────────────────────────────────────────────╯"
echo -e "${RESET}"

info "Selecting target: ${LUNCH_TARGET}"

lunch "${LUNCH_TARGET}"

ok "Build target selected: ${LUNCH_TARGET}"

# ============================================================
# Telegram
# ============================================================

notify_build_start

# ============================================================
# Build Cleanup
# ============================================================

if [[ ! -f "${BUILD_MARKER}" ]]; then

    section "First Build Cleanup"

    warn "No previous successful build detected"
    info "Running: make clean"
    info "This is the only full clean; build output will be kept afterwards."

    make clean || fail "make clean failed"

    ok "Full clean complete"

else

    section "Dirty Build Cleanup"

    info "Previous successful build detected"
    info "Keeping existing build output"
    info "Running: make installclean"

    make installclean || fail "make installclean failed"

    ok "Install clean complete"

fi

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

    notify_build_failed

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
# Find Artifacts
# ============================================================

section "Release Artifact"
info "Searching for the final Evolution-X ZIP (target_files and OTA helper ZIPs excluded)"

ARTIFACTS=()

# ------------------------------------------------------------
# ROM ZIP ONLY
# ------------------------------------------------------------

while IFS= read -r -d '' FILE; do

    ARTIFACTS+=("$FILE")

done < <(
    find "out/target/product/${DEVICE}" \
        -maxdepth 1 \
        -type f \
        -name "*.zip" \
        ! -name "*target_files*" \
        ! -name "*ota*" \
        -print0
)

# ============================================================
# Artifact Check
# ============================================================

if [[ ${#ARTIFACTS[@]} -eq 0 ]]; then

    warn "No ROM ZIP found"

    tg_send "⚠️ Evolution-X build completed

Device: ${DEVICE}
Variant: ${BUILD_VARIANT}

❌ No ROM ZIP was found.
Upload skipped."

else

    ok "Found ${#ARTIFACTS[@]} ROM ZIP(s)"

    for FILE in "${ARTIFACTS[@]}"; do

        echo
        info "$(basename "$FILE")"
        info "Size: $(du -h "$FILE" | cut -f1)"

    done

    # ========================================================
    # Upload
    # ========================================================

    for FILE in "${ARTIFACTS[@]}"; do

        PIXELDRAIN_URL=""
        GOFILE_URL=""

        echo

        section "Release Uploads"

        info "Artifact: $(basename "$FILE")"
        info "Destinations: PixelDrain + GoFile"
        info "ZIP only"

        # -------------------------------
        # PixelDrain
        # -------------------------------

        upload_pixeldrain "$FILE" || true

        # -------------------------------
        # GoFile
        # -------------------------------

        upload_gofile "$FILE" || true

        # -------------------------------
        # Telegram
        # -------------------------------

        notify_artifact "$FILE"

    done

fi

# ============================================================
# Finish
# ============================================================

JOB_END=$(date +%s)
TOTAL_MINUTES=$(((JOB_END - JOB_START) / 60))

section "Job Complete"

ok "Everything finished"
info "Total time: ${TOTAL_MINUTES} minutes"

notify_finished "${TOTAL_MINUTES}"

echo

echo -e "${GREEN}${BOLD}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                  EVOLUTION-X COMPLETE                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"
