#!/usr/bin/env bash
# update.sh — build the patched taskmanager applet to match the INSTALLED
# plasma-desktop version (the applet must match the running Plasma ABI), then
# publish to arches-local and install.
#
# Loud-fail gates:
#   * fullheight-launchers.patch no longer applies (prepare -F0)  -> rebase it
#   * upstream added/removed a QML file the CMakeLists lists       -> cmake error
#     (this is how the 6.7.0 Badge.qml removal would surface)
#   * compile error                                               -> makepkg aborts
# On any failure, your currently-installed applet is left untouched.
#
# Usage:
#   ./update.sh              # build for installed plasma-desktop, publish, install
#   ./update.sh 6.7.1        # target a specific version instead
#   ./update.sh --build-only # build only
#   ./update.sh --no-install # build + publish, don't pacman -U
#
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

PKG=arches-taskmanager-patched
REPO_DIR=/opt/arches-repo
REPO_DB=arches-local.db.tar.gz

BUILD_ONLY=0; NO_INSTALL=0; FORCE=0; TARGET_VER=""
for a in "$@"; do
  case "$a" in
    --build-only) BUILD_ONLY=1 ;;
    --no-install) NO_INSTALL=1 ;;
    --force) FORCE=1 ;;
    -*) echo "unknown arg: $a" >&2; exit 2 ;;
    *) TARGET_VER="$a" ;;
  esac
done

die() { echo "!! $*" >&2; exit 1; }
note() { echo "==> $*"; }

# Target version: arg, else the installed plasma-desktop version (sans pkgrel).
if [[ -z "$TARGET_VER" ]]; then
  TARGET_VER="$(pacman -Q plasma-desktop 2>/dev/null | awk '{print $2}' | cut -d- -f1)" \
    || die "plasma-desktop not installed; cannot determine target version"
fi
[[ -n "$TARGET_VER" ]] || die "could not determine target version"
note "Target plasma-desktop version: $TARGET_VER"

# Skip early if the installed applet already matches the target version.
installed="$(pacman -Q "$PKG" 2>/dev/null | awk '{print $2}' | cut -d- -f1 || true)"
if [[ "$installed" == "$TARGET_VER" && "$FORCE" != 1 ]]; then
  note "$PKG already built for plasma-desktop $TARGET_VER — nothing to do. (--force to rebuild)"
  exit 0
fi

# Point the PKGBUILD at the target version.
sed -i -E "s/^pkgver=.*/pkgver=$TARGET_VER/" PKGBUILD
sed -i -E "s/^pkgrel=.*/pkgrel=1/" PKGBUILD

note "Refreshing checksums (downloads plasma-desktop tarball)..."
updpkgsums

# Verify KDE signing keys present (loud).
mapfile -t keys < <(. ./PKGBUILD; printf '%s\n' "${validpgpkeys[@]}")
missing=()
for k in "${keys[@]}"; do gpg --list-keys "$k" >/dev/null 2>&1 || missing+=("$k"); done
((${#missing[@]})) && die "missing KDE signing keys: ${missing[*]} (gpg --recv-keys ${missing[*]})"

note "Building package (makepkg)..."
makepkg -Cf

pkgfile="$(ls -t ${PKG}-*-x86_64.pkg.tar.zst | head -1)"
[[ -f "$pkgfile" ]] || die "build succeeded but no package file found"
note "Built: $pkgfile"
((BUILD_ONLY)) && { note "--build-only: done."; exit 0; }

note "Publishing to arches-local [sudo]..."
sudo cp "$pkgfile" "$REPO_DIR/"
sudo repo-add "$REPO_DIR/$REPO_DB" "$REPO_DIR/$pkgfile"
((NO_INSTALL)) && { note "--no-install: published. Install with: sudo pacman -U $REPO_DIR/$pkgfile"; exit 0; }

note "Installing (sudo pacman -U)..."
sudo pacman -U --noconfirm "$REPO_DIR/$pkgfile"

cat <<EOF

Done. Installed $PKG $TARGET_VER.
Re-run this after each plasma-desktop upgrade to rebuild against the new ABI.
Activate (first install needs a re-login for the env file; later updates just):
    kquitapp6 plasmashell && plasmashell --replace &
EOF
