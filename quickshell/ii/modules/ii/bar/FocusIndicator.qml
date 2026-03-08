import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs

import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root

    Layout.fillHeight: true
    implicitWidth: focusActive ? rowLayout.implicitWidth + 16 : 0
    implicitHeight: Appearance.sizes.barHeight
    visible: focusActive
    clip: true

    property bool focusActive: false
    property string sessionName: ""
    property string countdown: ""
    property bool paused: false
    property int endTime: 0
    property int pauseStart: 0

    Behavior on implicitWidth {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    FileView {
        id: stateFile
        path: "/tmp/focus-mode.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let data = JSON.parse(stateFile.text());
                if (data.state === "done" || !data.state) {
                    root.focusActive = false;
                    return;
                }
                root.focusActive = (data.state === "active" || data.state === "paused");
                root.sessionName = data.session_name || "";
                root.paused = (data.state === "paused");
                root.endTime = data.end_time || 0;
                root.pauseStart = data.pause_start || 0;

                if (data.end_time && data.state === "active") {
                    updateCountdown(data.end_time);
                } else if (data.state === "paused" && data.pause_start) {
                    updatePauseDuration(data.pause_start);
                }
            } catch (e) {
                root.focusActive = false;
            }
        }
        onLoadFailed: (error) => {
            root.focusActive = false;
        }
    }

    Timer {
        id: countdownTimer
        // Tick every second when < 2 min remaining, otherwise every 30s
        interval: {
            if (!root.focusActive || root.paused) return 60000;
            let now = Math.floor(Date.now() / 1000);
            let remaining = root.endTime - now;
            return remaining <= 120 ? 1000 : 30000;
        }
        repeat: true
        running: root.focusActive
        onTriggered: {
            if (root.paused) {
                updatePauseDuration(root.pauseStart);
            } else {
                updateCountdown(root.endTime);
            }
        }
    }

    function updateCountdown(endTime) {
        let now = Math.floor(Date.now() / 1000);
        let remaining = endTime - now;
        if (remaining <= 0) {
            root.countdown = "0s";
            return;
        }
        let hours = Math.floor(remaining / 3600);
        let mins = Math.floor((remaining % 3600) / 60);
        let secs = remaining % 60;

        if (hours > 0) {
            root.countdown = hours + "h " + mins + "m";
        } else if (mins > 0) {
            if (remaining <= 60) {
                root.countdown = secs + "s";
            } else {
                root.countdown = mins + "m";
            }
        } else {
            root.countdown = secs + "s";
        }
    }

    function updatePauseDuration(pauseStart) {
        let now = Math.floor(Date.now() / 1000);
        let elapsed = now - pauseStart;
        let mins = Math.floor(elapsed / 60);
        let secs = elapsed % 60;
        root.countdown = "⏸ " + mins + ":" + String(secs).padStart(2, '0');
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: focusToggle.running = true
    }

    Process {
        id: focusToggle
        command: ["/bin/bash", "/home/pratik/.config/hypr/custom/scripts/focus-mode.sh"]
    }

    RowLayout {
        id: rowLayout
        spacing: 6
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8

        MaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            text: root.paused ? "pause_circle" : "target"
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.m3colors.m3onSecondaryContainer
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            elide: Text.ElideRight
            color: Appearance.colors.colOnLayer1
            text: {
                let name = root.sessionName;
                if (name.length > 12) name = name.substring(0, 12) + "…";
                return name + "  " + root.countdown;
            }
        }
    }
}
