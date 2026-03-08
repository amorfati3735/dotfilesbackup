import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.services

AbstractWidget {
    id: root

    required property var noteData
    required property int noteIndex
    property real targetX: 0
    property real targetY: 0
    x: targetX
    y: targetY

    implicitWidth: noteBox.implicitWidth
    implicitHeight: noteBox.implicitHeight

    draggable: true

    Timer {
        id: posSaveTimer
        interval: 1000
        onTriggered: {
            if (StickyNotes.updateNotePosition) {
                StickyNotes.updateNotePosition(root.noteData.timestamp, root.targetX, root.targetY)
            }
        }
    }

    onTargetXChanged: posSaveTimer.restart()
    onTargetYChanged: posSaveTimer.restart()

    onReleased: {
        root.targetX = root.x;
        root.targetY = root.y;
        if (StickyNotes.updateNotePosition) {
            StickyNotes.updateNotePosition(root.noteData.timestamp, root.targetX, root.targetY)
        }
    }

    StyledDropShadow {
        target: noteBox
    }

    Rectangle {
        id: noteBox
        implicitWidth: contentLayout.implicitWidth + 32
        implicitHeight: contentLayout.implicitHeight + 24
        radius: Appearance.rounding.small
        color: Appearance.colors.colSecondaryContainer
        border.width: 2
        border.color: Appearance.colors.colOutlineVariant

        // Subtle noise texture
        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                var w = width;
                var h = height;
                ctx.clearRect(0, 0, w, h);
                for (var i = 0; i < w * h * 0.03; i++) {
                    var x = Math.random() * w;
                    var y = Math.random() * h;
                    var a = Math.random() * 0.06;
                    ctx.fillStyle = "rgba(0,0,0," + a + ")";
                    ctx.fillRect(x, y, 1, 1);
                }
            }
        }

        ColumnLayout {
            id: contentLayout
            anchors.centerIn: parent
            spacing: 4

            MaterialSymbol {
                text: "format_quote"
                iconSize: 24
                color: Appearance.colors.colPrimary
                Layout.alignment: Qt.AlignLeft
                opacity: 0.7
                font.weight: Font.Bold
            }

            StyledText {
                id: noteText
                Layout.maximumWidth: 400
                text: root.noteData.content
                wrapMode: Text.Wrap
                color: Appearance.colors.colOnSecondaryContainer
                horizontalAlignment: Text.AlignLeft
                font {
                    family: Appearance.font.family.reading
                    pixelSize: Appearance.font.pixelSize.large
                    weight: Font.Normal
                }
            }
        }
    }
}
