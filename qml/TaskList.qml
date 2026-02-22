/*
    SPDX-FileCopyrightText: 2012-2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import plasma.applet.org.kde.plasma.taskmanager as TaskManagerApplet

GridLayout {
    property bool animating: false
    property string CUSTOM_OVERRIDE_MARKER: "custom_tasklist_v1"
    Component.onCompleted: console.warn("CUSTOM_TASKLIST_LOADED rows=" + rows + " cols=" + columns + " launchers=" + fullHeightLauncherCount)

    rowSpacing: 0
    columnSpacing: 0

    property int animationsRunning: 0
    onAnimationsRunningChanged: {
        animating = animationsRunning > 0;
    }

    required property int count

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

    readonly property real minimumWidth: children
        .filter(item => item.visible && item.width > 0)
        .reduce((minimumWidth, item) => Math.min(minimumWidth, item.width), Infinity)

    // Count how many children are full-height launchers (rowSpan = all rows).
    // These each occupy exactly 1 column regardless of stripeCount.
    readonly property int fullHeightLauncherCount: {
        let n = 0;
        for (let i = 0; i < children.length; ++i) {
            if (children[i].isFullHeightLauncher === true) {
                ++n;
            }
        }
        return n;
    }

    readonly property int stripeCount: {
        if (Plasmoid.configuration.maxStripes === 1) {
            return 1;
        }

        // Use the first non-full-height-launcher child's implicitHeight/Width for
        // the stripeSizeLimit calculation, so that full-height launchers (which
        // have a larger preferredHeight) don't incorrectly reduce stripeCount.
        // Find a Task child that is not a full-height launcher to use as the
        // reference for implicitHeight. Skip non-Task children (e.g. Repeater).
        let referenceChild = null;
        for (let i = 0; i < children.length; ++i) {
            const child = children[i];
            if (child.hasOwnProperty("isFullHeightLauncher") && !child.isFullHeightLauncher) {
                referenceChild = child;
                break;
            }
        }
        // Fall back to any Task child if all are full-height launchers.
        if (!referenceChild) {
            for (let i = 0; i < children.length; ++i) {
                if (children[i].hasOwnProperty("isFullHeightLauncher")) {
                    referenceChild = children[i];
                    break;
                }
            }
        }
        if (!referenceChild) {
            referenceChild = children[0];
        }

        // The maximum number of stripes allowed by the applet's size
        const stripeSizeLimit = vertical
            ? Math.floor(parent.width / referenceChild.implicitWidth)
            : Math.floor(parent.height / referenceChild.implicitHeight)
        const maxStripes = Math.min(Plasmoid.configuration.maxStripes, stripeSizeLimit)

        if (Plasmoid.configuration.forceStripes) {
            return maxStripes;
        }

        // When there are full-height launchers, the auto-shrink heuristic
        // (reducing stripes when few tasks are present) produces wrong results
        // because it only counts non-launcher tasks against panel width.
        // Respect the user's maxStripes setting directly in that case.
        const nonLaunchers = count - fullHeightLauncherCount;
        if (fullHeightLauncherCount > 0 && nonLaunchers > 0) {
            return maxStripes;
        }

        // The number of tasks that will fill a "stripe" before starting the next one
        const maxTasksPerStripe = vertical
            ? Math.ceil(parent.height / TaskManagerApplet.LayoutMetrics.preferredMinHeight())
            : Math.ceil(parent.width / TaskManagerApplet.LayoutMetrics.preferredMinWidth())

        return Math.min(Math.ceil(nonLaunchers / maxTasksPerStripe), maxStripes)
    }

    readonly property int orthogonalCount: {
        // Full-height launchers each occupy 1 column; remaining items share
        // columns in the normal stripeCount rows.
        const nonLauncherCount = count - fullHeightLauncherCount;
        return fullHeightLauncherCount + Math.ceil(nonLauncherCount / stripeCount);
    }

    rows: vertical ? orthogonalCount : stripeCount
    columns: vertical ? stripeCount : orthogonalCount
}
