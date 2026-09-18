#!/bin/bash
# ── Thin adapter ─────────────────────────────────────────────────────────────
# The Fusion HAT installer lives in the fusion-hat repository. This file only
# forwards to it, so that existing documentation links keep working while the
# install logic is maintained in exactly one place.
#
#   curl -sSL https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/main/install-fusion-hat.sh | sudo bash
#
# To install/test a specific branch of fusion-hat:
#   FUSION_HAT_BRANCH=<branch> sudo -E bash install-fusion-hat.sh
# ─────────────────────────────────────────────────────────────────────────────
set -e

# Default to the release branch (the fusion-hat repository has no "main" branch)
FUSION_HAT_BRANCH="${FUSION_HAT_BRANCH:-v1}"
INSTALLER_URL="https://raw.githubusercontent.com/sunfounder/fusion-hat/${FUSION_HAT_BRANCH}/install.sh"

TMP_SCRIPT="$(mktemp /tmp/fusion-hat-install.XXXXXX)"
trap 'rm -f "$TMP_SCRIPT"' EXIT

if ! curl -fsSL "$INSTALLER_URL" -o "$TMP_SCRIPT"; then
    echo "Network error: failed to download ${INSTALLER_URL}"
    exit 1
fi

FUSION_HAT_BRANCH="$FUSION_HAT_BRANCH" bash "$TMP_SCRIPT" "$@"
