#!/usr/bin/env bash
# clean.sh
#
# Removes all build artifacts and installed files for the patched taskmanager applet.
#
# Usage:
#   ./clean.sh           # remove build dir and installed .so
#   ./clean.sh --all     # also delete the upstream source clone at /tmp

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
UPSTREAM_CLONE="/tmp/plasma-desktop-upstream-src"

# Detect lib dir the same way build-and-install.sh does.
if [[ -d /usr/lib64/qt6 ]]; then
    LOCAL_LIB="lib64"
else
    LOCAL_LIB="lib"
fi

PLUGIN_DIR="$HOME/.local/$LOCAL_LIB/qt6/plugins/plasma/applets"
INSTALLED_SO="$PLUGIN_DIR/org.kde.plasma.taskmanager.so"
ENV_FILE="$HOME/.config/plasma-workspace/env/env.sh"
LOCAL_PLUGIN_BASE="$HOME/.local/$LOCAL_LIB/qt6/plugins"

# ---------------------------------------------------------------------------
# Build directory
# ---------------------------------------------------------------------------
if [[ -d "$BUILD_DIR" ]]; then
    echo "==> Removing build directory: $BUILD_DIR"
    rm -rf "$BUILD_DIR"
else
    echo "==> Build directory not present, skipping: $BUILD_DIR"
fi

# ---------------------------------------------------------------------------
# Installed .so
# ---------------------------------------------------------------------------
if [[ -f "$INSTALLED_SO" ]]; then
    echo "==> Removing installed plugin: $INSTALLED_SO"
    rm -f "$INSTALLED_SO"
else
    echo "==> Installed plugin not present, skipping: $INSTALLED_SO"
fi

# ---------------------------------------------------------------------------
# QT_PLUGIN_PATH line from env.sh
# ---------------------------------------------------------------------------
if [[ -f "$ENV_FILE" ]] && grep -qF "$LOCAL_PLUGIN_BASE" "$ENV_FILE"; then
    echo "==> Removing QT_PLUGIN_PATH entry from $ENV_FILE"
    # Delete the comment line and the export line added by build-and-install.sh.
    sed -i '/# Added by plasma-taskmanager-fullheight-launchers/d' "$ENV_FILE"
    sed -i "\|export QT_PLUGIN_PATH=.*${LOCAL_PLUGIN_BASE}|d" "$ENV_FILE"
fi

# ---------------------------------------------------------------------------
# Upstream source clone (opt-in)
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "--all" ]]; then
    if [[ -d "$UPSTREAM_CLONE" ]]; then
        echo "==> Removing upstream clone: $UPSTREAM_CLONE"
        rm -rf "$UPSTREAM_CLONE"
    else
        echo "==> Upstream clone not present, skipping: $UPSTREAM_CLONE"
    fi
fi

echo ""
echo "Done. Restart plasmashell to revert to the system taskmanager:"
echo "    kquitapp6 plasmashell && plasmashell --replace &"
