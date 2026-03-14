import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions as CF
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "todo"

    implicitHeight: backgroundShape.implicitHeight
    implicitWidth: backgroundShape.implicitWidth

    StyledDropShadow {
        target: backgroundShape
    }

    Rectangle {
        id: backgroundShape
        color: Appearance.colors.colPrimaryContainer
        implicitWidth: 350
        implicitHeight: Math.max(150, layout.implicitHeight + 40)
        radius: Appearance.rounding.large
        
        ColumnLayout {
            id: layout
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 20
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                MaterialSymbol {
                    text: "checklist"
                    color: Appearance.colors.colPrimary
                    iconSize: Appearance.font.pixelSize.large
                }
                StyledText {
                    text: "To-Do List"
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnPrimaryContainer
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: CF.ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.2)
            }

            Repeater {
                model: Todo.list
                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    MaterialSymbol {
                        text: modelData.done ? "check_circle" : "radio_button_unchecked"
                        color: modelData.done ? Appearance.colors.colPrimary : Appearance.colors.colOnPrimaryContainer
                        iconSize: Appearance.font.pixelSize.normal
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (modelData.done) {
                                    Todo.markUnfinished(index)
                                } else {
                                    Todo.markDone(index)
                                }
                            }
                        }
                    }
                    StyledText {
                        text: modelData.content
                        color: modelData.done ? CF.ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.5) : Appearance.colors.colOnPrimaryContainer
                        font.strikeout: modelData.done
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        font.weight: Font.Medium
                    }
                    MaterialSymbol {
                        text: "delete"
                        color: CF.ColorUtils.transparentize(Appearance.colors.colError, 0.7)
                        iconSize: Appearance.font.pixelSize.normal
                        visible: deleteArea.containsMouse
                        MouseArea {
                            id: deleteArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Todo.deleteItem(index)
                        }
                    }
                }
            }

            StyledText {
                visible: Todo.list.length === 0
                text: "No tasks here!"
                color: CF.ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.5)
                font.italic: true
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 20
            }
        }
    }
}
