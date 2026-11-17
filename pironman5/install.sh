#!/bin/bash
# ============================================================
# DEPRECATED - do not use, do not extend.
#
# The Pironman 5 installer lives with the product, on the current `v1` branch
# of that repository (`1.3.x` is deprecated):
#   https://raw.githubusercontent.com/sunfounder/pironman5/v1/install.sh
#   https://gitee.com/sunfounder/pironman5/raw/v1/install.sh      (China mirror)
#
# This file is kept only so that installations whose `pironman5 update` still
# points at this URL keep working: it forwards every argument to the installer
# above and does nothing else. Installations coming from `1.3.x` are moved to
# the `v1` installer, which clones and runs the `v1` product code.
#
# Policy for this repository: product installers belong in the product
# repository; this repository keeps shared tooling (tools/) and installers for
# products that have no repository of their own.
# ============================================================
set -u

say() { printf '%s\n' "$*" >&2; }

say "NOTE: this installer is deprecated. It now forwards to the Pironman 5"
say "      installer maintained in the sunfounder/pironman5 repository (v1)."

BRANCH="${PIRONMAN5_INSTALLER_BRANCH:-v1}"
URLS=(
    "https://raw.githubusercontent.com/sunfounder/pironman5/${BRANCH}/install.sh"
    "https://gitee.com/sunfounder/pironman5/raw/${BRANCH}/install.sh"
)

TMP_SCRIPT="$(mktemp /tmp/pironman5-install.XXXXXX.sh)"
trap 'rm -f "$TMP_SCRIPT"' EXIT INT TERM

DOWNLOADED=false
for url in "${URLS[@]}"; do
    if curl -fsSL "$url" -o "$TMP_SCRIPT"; then
        DOWNLOADED=true
        break
    fi
done

if [ "$DOWNLOADED" != true ]; then
    say "ERROR: could not download the Pironman 5 installer from:"
    for url in "${URLS[@]}"; do say "  $url"; done
    say "Check the network connection and run the installer from the URL above."
    exit 1
fi

bash "$TMP_SCRIPT" "$@"
RC=$?
exit "$RC"
