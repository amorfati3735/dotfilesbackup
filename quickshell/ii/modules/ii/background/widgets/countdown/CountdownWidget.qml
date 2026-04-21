import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "countdown"

    implicitWidth: 380
    implicitHeight: 220

    // Config
    property string targetDateStr: Config.options.background.widgets.countdown.targetDate
    property string label: Config.options.background.widgets.countdown.label

    // Countdown math
    property date targetDate: new Date(targetDateStr)
    property date now: new Date()
    property int totalDays: {
        let start = new Date(Config.options.background.widgets.countdown.startDate)
        let end = targetDate
        return Math.max(1, Math.ceil((end - start) / 86400000))
    }
    property int daysLeft: Math.max(0, Math.ceil((targetDate - now) / 86400000))
    property int daysElapsed: totalDays - daysLeft
    property real progress: Math.min(1.0, daysElapsed / totalDays)
    property bool isComplete: daysLeft <= 0

    // Retro dark palette
    property color cardBg: "#1a1a1a"
    property color cardBorder: "#333333"
    property color dotLit: "#e0e0e0"
    property color dotDim: "#3a3a3a"
    property color textMain: "#e8e8e8"
    property color textSub: "#999999"
    property color btnBg: "#333333"
    property color btnText: "#e8e8e8"

    FontLoader {
        id: dotoFont
        source: "file:///home/pratik/.local/share/fonts/Doto-Bold.ttf"
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root.now = new Date()
    }

    StyledRectangularShadow {
        target: card
    }

    Rectangle {
        id: card
        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin
        radius: 16
        color: root.cardBg
        border.color: root.cardBorder
        border.width: 1
        clip: true

        // Noise texture
        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                var w = width; var h = height;
                ctx.clearRect(0, 0, w, h);
                for (var i = 0; i < w * h * 0.02; i++) {
                    var x = Math.random() * w;
                    var y = Math.random() * h;
                    var a = Math.random() * 0.05;
                    ctx.fillStyle = "rgba(255,255,255," + a + ")";
                    ctx.fillRect(x, y, 1, 1);
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 0

            // Title
            Text {
                text: root.label.toUpperCase()
                color: root.textMain
                font.family: dotoFont.name
                font.pixelSize: 28
                font.weight: Font.Bold
                font.letterSpacing: 2
            }

            Item { Layout.preferredHeight: 14 }

            // Stats row
            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: "ELAPSED: " + root.daysElapsed + " DAYS"
                    color: root.textMain
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "LEFT: " + root.daysLeft + " DAYS"
                    color: root.textMain
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
            }

            Item { Layout.preferredHeight: 12 }

            // Dot-matrix progress bar
            Canvas {
                id: dotBar
                Layout.fillWidth: true
                Layout.preferredHeight: 20

                property real prog: root.progress

                onProgChanged: requestPaint()
                onWidthChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    var w = width;
                    var h = height;
                    ctx.clearRect(0, 0, w, h);

                    var dotSize = 4;
                    var gap = 2;
                    var step = dotSize + gap;
                    var cols = Math.floor(w / step);
                    var rows = Math.floor(h / step);
                    var totalDots = cols * rows;
                    var litDots = Math.round(totalDots * prog);

                    var offsetX = (w - cols * step + gap) / 2;
                    var offsetY = (h - rows * step + gap) / 2;

                    for (var r = 0; r < rows; r++) {
                        for (var c = 0; c < cols; c++) {
                            var idx = r * cols + c;
                            var x = offsetX + c * step;
                            var y = offsetY + r * step;
                            ctx.fillStyle = idx < litDots ? root.dotLit : root.dotDim;
                            ctx.fillRect(x, y, dotSize, dotSize);
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // Bottom row: message + button
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    Layout.fillWidth: true
                    text: {
                        if (root.isComplete) return "THE DAY HAS ARRIVED\nTIME TO GO";
                        if (root.progress > 0.9) return "ALMOST THERE\nSTAY FOCUSED";
                        if (root.progress > 0.5) return "PAST THE HALFWAY MARK\nKEEP GOING";
                        return "COUNTDOWN IN PROGRESS\nSTAY PATIENT";
                    }
                    color: root.textSub
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    lineHeight: 1.3
                }

                // Percentage badge
                Rectangle {
                    implicitWidth: pctText.implicitWidth + 24
                    implicitHeight: 32
                    radius: 16
                    color: root.btnBg
                    border.color: root.cardBorder
                    border.width: 1

                    Text {
                        id: pctText
                        anchors.centerIn: parent
                        text: Math.round(root.progress * 100) + "%"
                        color: root.btnText
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }
                }
            }
        }
    }
}
