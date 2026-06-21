#!/bin/sh
# Installed by the arches-taskmanager-patched package.
# Prepends the overlay plugin root so plasmashell loads our patched
# org.kde.plasma.taskmanager.so in preference to plasma-desktop's stock copy.
# Sourced by startplasma from /etc/xdg/plasma-workspace/env/ at session start.
export QT_PLUGIN_PATH="/usr/lib/qt6-overlay/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
