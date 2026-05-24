import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Item {
    id: root

    // mirrored from /tmp/cram-state.json
    property string mode: ""           // "active" | "upcoming" | "done" | ""
    property int    idx: -1
    property string title: ""
    property string hint: ""
    property string kind: ""
    property int    startTs: 0
    property int    endTs: 0
    property int    doneCount: 0
    property int    total: 10
    property bool   paused: false

    property string display: ""         // text shown in bar

    function fmtRemaining(secs) {
        if (secs < 0) secs = 0;
        let h = Math.floor(secs / 3600);
        let m = Math.floor((secs % 3600) / 60);
        let s = secs % 60;
        if (h > 0) return h + "h " + m + "m";
        if (m > 0) return (secs <= 60) ? (s + "s") : (m + "m");
        return s + "s";
    }

    function recompute() {
        let now = Math.floor(Date.now() / 1000);
        if (root.mode === "active") {
            let rem = root.endTs - now;
            root.display = root.title + "  " + fmtRemaining(rem);
        } else if (root.mode === "upcoming") {
            let until = root.startTs - now;
            root.display = "next: " + root.title + " in " + fmtRemaining(until);
        } else if (root.mode === "done") {
            root.display = "✅ all blocks done";
        } else {
            root.display = "";
        }
    }

    readonly property bool shown: root.mode === "active" || root.mode === "upcoming" || root.mode === "done"

    Layout.fillHeight: true
    implicitWidth: shown ? rowLayout.implicitWidth + 16 : 0
    implicitHeight: Appearance.sizes.barHeight
    visible: shown
    clip: true

    FileView {
        id: stateFile
        path: "/tmp/cram-state.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let d = JSON.parse(stateFile.text());
                root.mode      = d.state || "";
                root.idx       = d.idx ?? -1;
                root.title     = d.title || d.next_title || "";
                root.hint      = d.hint || "";
                root.kind      = d.kind || d.next_kind || "";
                root.startTs   = d.start_ts || 0;
                root.endTs     = d.end_ts || 0;
                root.doneCount = d.done_count || 0;
                root.total     = d.total || 10;
                root.paused    = !!d.paused;
                root.recompute();
            } catch (e) {
                root.mode = "";
            }
        }
        onLoadFailed: { root.mode = ""; }
    }

    Timer {
        id: ticker
        // Tick fast (1s) when <2 min left; else every 30s
        interval: {
            if (root.mode === "")
                return 60000;
            let now = Math.floor(Date.now() / 1000);
            let target = (root.mode === "active") ? root.endTs : root.startTs;
            let rem = target - now;
            return rem <= 120 ? 1000 : 30000;
        }
        repeat: true
        running: root.shown
        onTriggered: root.recompute()
    }

    RowLayout {
        id: rowLayout
        spacing: 6
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8

        MaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            text: {
                if (root.paused)            return "pause_circle";
                if (root.mode === "done")   return "celebration";
                if (root.mode === "upcoming") return "schedule";
                if (root.kind === "num")    return "calculate";
                if (root.kind === "theory") return "menu_book";
                if (root.kind === "sheets") return "sticky_note_2";
                if (root.kind === "buffer") return "bedtime";
                return "target";
            }
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.m3colors.m3onSecondaryContainer
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            elide: Text.ElideRight
            color: Appearance.colors.colOnLayer1
            text: {
                let label = root.display;
                // truncate the title portion if very long
                if (label.length > 40) label = label.substring(0, 39) + "…";
                return "[" + root.doneCount + "/" + root.total + "] " + label;
            }
        }
    }

    // Click to mark current block done; right-click for status notif
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton && root.mode === "active") {
                cramDone.running = true;
            } else if (mouse.button === Qt.RightButton) {
                cramStatus.running = true;
            }
        }
    }

    Process {
        id: cramDone
        command: ["/home/pratik/scripts/cram", "done"]
    }

    Process {
        id: cramStatus
        command: ["/bin/bash", "-c",
            "notify-send -a 'OS Cram' '📋 Schedule' \"$(/home/pratik/scripts/cram status)\""]
    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
        }
    }
}
