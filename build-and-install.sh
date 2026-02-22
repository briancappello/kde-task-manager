#!/usr/bin/env bash
# build-and-install.sh
#
# Builds a modified plasma-desktop taskmanager applet that renders pinned
# launchers as full-height square icons on multi-row horizontal panels,
# and installs it to ~/.local so it takes precedence over the system copy.
#
# Tested on: Fedora 42 Asahi Remix (aarch64), plasma-desktop 6.6.0, Qt 6.10.2
#
# Usage:
#   ./build-and-install.sh          # build + install + print restart instructions
#   ./build-and-install.sh --clean  # wipe build dir first, then build + install

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
UPSTREAM_TAG="v6.6.0"
UPSTREAM_REPO="https://invent.kde.org/plasma/plasma-desktop"
UPSTREAM_CLONE="/tmp/plasma-desktop-upstream-src"

# ---------------------------------------------------------------------------
# 0. Optional --clean
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "--clean" ]]; then
    echo "==> Removing build directory..."
    rm -rf "$BUILD_DIR"
fi

# ---------------------------------------------------------------------------
# 1. Install build dependencies (Fedora / dnf)
# ---------------------------------------------------------------------------
if command -v dnf &>/dev/null; then
    echo "==> Installing build dependencies via dnf..."
    sudo dnf install -y \
        cmake ninja-build gcc-c++ \
        extra-cmake-modules \
        kf6-kconfig-devel \
        kf6-ki18n-devel \
        kf6-kio-devel \
        kf6-knotifications-devel \
        kf6-kservice-devel \
        kf6-kwindowsystem-devel \
        plasma-activities-devel \
        plasma-activities-stats-devel \
        libplasma-devel \
        plasma-workspace-devel \
        kf6-kitemmodels-devel \
        libksysguard-devel \
	qt6-qtbase-devel \
        qt6-qtdeclarative-devel
else
    echo "==> dnf not found; assuming build dependencies are already installed."
fi

# ---------------------------------------------------------------------------
# 2. Fetch upstream sources for all QML files that we do NOT patch
#    (we only need the non-modified files from upstream to compile)
# ---------------------------------------------------------------------------
if [[ ! -d "$UPSTREAM_CLONE" ]]; then
    echo "==> Cloning upstream plasma-desktop at tag $UPSTREAM_TAG (sparse)..."
    git clone --depth 1 --branch "$UPSTREAM_TAG" --filter=blob:none --sparse \
        "$UPSTREAM_REPO" "$UPSTREAM_CLONE"
    git -C "$UPSTREAM_CLONE" sparse-checkout set applets/taskmanager kcms/recentFiles
else
    echo "==> Upstream clone already present at $UPSTREAM_CLONE"
fi

UPSTREAM_QML="$UPSTREAM_CLONE/applets/taskmanager"

# ---------------------------------------------------------------------------
# 3. Assemble a build tree:
#    - CMakeLists.txt, C++ sources, resources  from upstream
#    - QML files: patched ones from this repo, rest from upstream
# ---------------------------------------------------------------------------
BUILD_SRC="$BUILD_DIR/src"
mkdir -p "$BUILD_SRC/qml/code"

echo "==> Assembling build source tree at $BUILD_SRC..."

# C++ sources, resources, config files from upstream
for f in backend.cpp backend.h smartlauncherbackend.cpp smartlauncherbackend.h \
          smartlauncheritem.cpp smartlauncheritem.h main.xml metadata.json; do
    cp "$UPSTREAM_QML/$f" "$BUILD_SRC/$f"
done
# kactivitymanagerd_plugins_settings.kcfgc/.kcfg live outside the taskmanager dir
cp "$UPSTREAM_CLONE/kcms/recentFiles/kactivitymanagerd_plugins_settings.kcfgc" \
   "$BUILD_SRC/kactivitymanagerd_plugins_settings.kcfgc"
cp "$UPSTREAM_CLONE/kcms/recentFiles/kactivitymanagerd_plugins_settings.kcfg" \
   "$BUILD_SRC/kactivitymanagerd_plugins_settings.kcfg"

# Use our CMakeLists.txt
cp "$SCRIPT_DIR/CMakeLists.txt" "$BUILD_SRC/CMakeLists.txt"

# Copy all upstream QML files first
cp "$UPSTREAM_QML"/qml/*.qml "$BUILD_SRC/qml/"
cp "$UPSTREAM_QML"/qml/code/*.js "$BUILD_SRC/qml/code/"

# Overlay our patched QML files (overwrite upstream copies)
for f in Task.qml TaskList.qml main.qml; do
    if [[ -f "$SCRIPT_DIR/qml/$f" ]]; then
        cp "$SCRIPT_DIR/qml/$f" "$BUILD_SRC/qml/$f"
        echo "    patched: $f"
    fi
done

# ---------------------------------------------------------------------------
# 4. Configure + build
# ---------------------------------------------------------------------------
mkdir -p "$BUILD_DIR/cmake-build"
# Remove stale CMake cache so generator/compiler detection is always fresh.
rm -f "$BUILD_DIR/cmake-build/CMakeCache.txt"

# Prefer ninja if available, fall back to make.
if command -v ninja &>/dev/null; then
    CMAKE_GENERATOR="Ninja"
elif command -v ninja-build &>/dev/null; then
    CMAKE_GENERATOR="Ninja"
    export CMAKE_MAKE_PROGRAM="$(command -v ninja-build)"
else
    echo "==> ninja not found, falling back to Unix Makefiles"
    CMAKE_GENERATOR="Unix Makefiles"
fi

echo "==> Configuring (generator: $CMAKE_GENERATOR)..."
cmake -S "$BUILD_SRC" -B "$BUILD_DIR/cmake-build" -G "$CMAKE_GENERATOR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTING=OFF

echo "==> Building..."
cmake --build "$BUILD_DIR/cmake-build" --parallel

# ---------------------------------------------------------------------------
# 5. Install .so to ~/.local
# ---------------------------------------------------------------------------
# Detect lib dir: use lib64 if the system Qt lives there, otherwise lib.
if [[ -d /usr/lib64/qt6 ]]; then
    LOCAL_LIB="lib64"
else
    LOCAL_LIB="lib"
fi

PLUGIN_DIR="$HOME/.local/$LOCAL_LIB/qt6/plugins/plasma/applets"
mkdir -p "$PLUGIN_DIR"
cp "$BUILD_DIR/cmake-build/bin/plasma/applets/org.kde.plasma.taskmanager.so" \
   "$PLUGIN_DIR/org.kde.plasma.taskmanager.so"
echo "==> Installed: $PLUGIN_DIR/org.kde.plasma.taskmanager.so"

# ---------------------------------------------------------------------------
# 6. Ensure env.sh sets QT_PLUGIN_PATH
# ---------------------------------------------------------------------------
ENV_FILE="$HOME/.config/plasma-workspace/env/env.sh"
mkdir -p "$(dirname "$ENV_FILE")"
touch "$ENV_FILE"

LOCAL_PLUGIN_BASE="$HOME/.local/$LOCAL_LIB/qt6/plugins"
if ! grep -qF "$LOCAL_PLUGIN_BASE" "$ENV_FILE"; then
    echo "==> Adding QT_PLUGIN_PATH to $ENV_FILE..."
    cat >> "$ENV_FILE" <<EOF

# Added by plasma-taskmanager-fullheight-launchers build-and-install.sh
export QT_PLUGIN_PATH="$LOCAL_PLUGIN_BASE\${QT_PLUGIN_PATH:+:\$QT_PLUGIN_PATH}"
EOF
fi

# ---------------------------------------------------------------------------
# 7. Done
# ---------------------------------------------------------------------------
echo ""
echo "Done! To activate the new build, restart plasmashell:"
echo "    kquitapp6 plasmashell && plasmashell --replace &"
echo ""
echo "Or log out and back in."
