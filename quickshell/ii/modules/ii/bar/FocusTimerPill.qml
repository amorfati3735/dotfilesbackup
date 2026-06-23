import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import qs
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    Layout.fillHeight: true
    implicitWidth: visible ? inner.implicitWidth + 16 : 0
    implicitHeight: Appearance.sizes.barHeight

    property var _session: null
    property var _now: Date.now()
    property var _elapsed: 0

    Timer {
        interval: 1000
        repeat: true
        running: root._session !== null
        onTriggered: {
            root._now = Date.now()
            root.recalc()
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: fetcher.running = true
    }

    function recalc() {
        if (!root._session) { root._elapsed = 0; return }
        var base = root._now - root._session.startedAt - (root._session.pausedMs || 0)
        if (root._session.pausedAt) base -= (root._now - root._session.pausedAt)
        root._elapsed = Math.max(0, base)
    }

    function displayMs() {
        if (!root._session) return 0
        if (root._session.timerTargetMs) {
            var remaining = root._session.timerTargetMs - root._elapsed
            return Math.max(0, remaining)
        }
        return root._elapsed
    }

    function fmt(ms) {
        if (ms < 0) ms = 0
        var s = Math.floor(ms / 1000)
        var h = Math.floor(s / 3600)
        var m = Math.floor((s % 3600) / 60)
        s = s % 60
        var pad2 = function(n) { return ('0' + n).slice(-2) }
        if (h > 0) return pad2(h) + ':' + pad2(m) + ':' + pad2(s)
        return pad2(m) + ':' + pad2(s)
    }

    function dotColor() {
        if (!root._session) return "transparent"
        if (root._session.pausedAt) return "#f59e0b"
        if (root._session.timerTargetMs) {
            var pct = root._elapsed / root._session.timerTargetMs
            if (pct > 0.85) return "#ef4444"
            return "#f97316"
        }
        return "#22c55e"
    }

    function isTimer() {
        return root._session && root._session.timerTargetMs
    }

    Process {
        id: fetcher
        command: ["/home/pratik/.config/quickshell/ii/scripts/calc-running-session.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var json = JSON.parse(text.trim())
                    if (json && json.id) {
                        root._session = json
                        root._now = Date.now()
                        root.recalc()
                    } else {
                        root._session = null
                    }
                } catch (_) {}
            }
        }
    }

    visible: root._session !== null

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
                width: 5; height: 5; radius: 2.5
                color: root.dotColor()
            }

            StyledText {
                text: root.fmt(root.displayMs())
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer1
            }

            StyledText {
                text: root._session?.subject ?? ''
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.6)
                visible: !root.isTimer()
            }

            StyledText {
                text: "TIMER"
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Bold
                color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.6)
                visible: root.isTimer()
            }
        }
    }
}
