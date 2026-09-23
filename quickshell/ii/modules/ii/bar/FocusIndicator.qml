import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// Low-resource focus-mode indicator for the LAlt+F focus system.
// Event-driven: a FileView watcher on /tmp/focus-mode.json (no polling), plus a
// slow timer that only speeds up in the final minute (or while paused).
Item {
    id: root

    property bool focusActive: false
    property bool paused: false
    property string sessionName: ""
    property string countdown: ""
    property double endTime: 0
    property double pauseStart: 0

    Layout.fillHeight: true
    implicitWidth: visible ? rowLayout.implicitWidth + 24 : 0
    implicitHeight: Appearance.sizes.barHeight
    visible: focusActive
    clip: true

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    FileView {
        id: stateFile

        path: "/tmp/focus-mode.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.applyState(stateFile.text())
        onLoadFailed: (error) => {
            root.focusActive = false;
        }
    }

    function applyState(text) {
        try {
            let data = JSON.parse(text);
            if (!data || (data.state !== "active" && data.state !== "paused")) {
                root.focusActive = false;
                return;
            }
            root.focusActive = true;
            root.paused = (data.state === "paused");
            root.sessionName = data.session_name || "";
            root.endTime = data.end_time || 0;
            root.pauseStart = data.pause_start || 0;
            root.tick();
        } catch (e) {
            root.focusActive = false;
        }
    }

    function tick() {
        let now = Math.floor(Date.now() / 1000);
        if (root.paused && root.pauseStart > 0) {
            root.countdown = "⏸ " + root.fmt(now - root.pauseStart);
        } else if (root.endTime > 0) {
            root.countdown = root.fmt(Math.max(0, root.endTime - now));
        } else {
            root.countdown = "";
        }
    }

    function fmt(secs) {
        secs = Math.max(0, Math.floor(secs));
        let h = Math.floor(secs / 3600);
        let m = Math.floor((secs % 3600) / 60);
        let s = secs % 60;
        let p2 = function(n) { return (n < 10 ? "0" : "") + n; };
        if (h > 0)
            return h + "h " + p2(m) + "m";
        if (m > 0)
            return m + "m";
        return s + "s";
    }

    Timer {
        id: ticker

        repeat: true
        running: root.focusActive
        interval: {
            if (!root.focusActive)
                return 60000;
            if (root.paused)
                return 1000;
            let remaining = root.endTime - Math.floor(Date.now() / 1000);
            return remaining <= 60 ? 1000 : 30000;
        }
        onTriggered: root.tick()
    }

    Rectangle {
        id: inner

        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        radius: 20
        color: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 0.5)

        RowLayout {
            id: rowLayout

            anchors.centerIn: parent
            spacing: 5

            Rectangle {
                width: 5
                height: 5
                radius: 2.5
                color: root.paused ? "#f59e0b" : "#22c55e"
            }

            StyledText {
                text: root.countdown
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer1
            }

            StyledText {
                visible: root.sessionName.length > 0
                text: {
                    let name = root.sessionName;
                    return name.length > 14 ? name.substring(0, 14) + "…" : name;
                }
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.6)
            }
        }
    }
}
