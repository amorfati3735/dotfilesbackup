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
    property bool _initialized: false
    x: targetX
    y: targetY

    implicitWidth: noteBox.implicitWidth
    implicitHeight: noteBox.implicitHeight

    draggable: true

    Component.onCompleted: _initialized = true

    onReleased: {
        root.targetX = root.x;
        root.targetY = root.y;
        if (_initialized) {
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
