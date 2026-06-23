import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "dayprogress"

    readonly property real cardPadding: 18
    readonly property real blockCount: 56

    implicitHeight: contentColumn.implicitHeight + cardPadding * 2
    implicitWidth: 320

    readonly property color cardColor: Appearance.colors.colPrimaryContainer
    readonly property color onCardColor: Appearance.colors.colOnPrimaryContainer
    readonly property color accentColor: Appearance.colors.colPrimary
    readonly property color dimBlockColor: ColorUtils.transparentize(accentColor, 0.82)

    property real dayProgress: 0
    property int currentHour: 0
    property string timeString: ""
    property string remainingString: ""
    property string percentString: ""
    property int filledBlocks: 0

    Timer {
        interval: 1000
        running: Config.options.background.widgets.dayprogress.enable && GlobalStates.vibecodeWidgetsEnabled
        repeat: true
        onTriggered: updateProgress()
    }

    Component.onCompleted: updateProgress()

    function updateProgress() {
        var now = new Date();
        currentHour = now.getHours();
        var currentMinute = now.getMinutes();
        var currentSecond = now.getSeconds();
        var msInDay = 86400000;
        var elapsedMs = (currentHour * 3600 + currentMinute * 60 + currentSecond) * 1000 + now.getMilliseconds();
        dayProgress = Math.min(1, elapsedMs / msInDay);
        filledBlocks = Math.round(dayProgress * blockCount);
        timeString = ("0" + currentHour).slice(-2) + ":" + ("0" + currentMinute).slice(-2);
        var remainingMs = msInDay - elapsedMs;
        var remainingH = Math.floor(remainingMs / 3600000);
        var remainingM = Math.floor((remainingMs % 3600000) / 60000);
        remainingString = ("0" + remainingH).slice(-2) + "H " + ("0" + remainingM).slice(-2) + "M";
        percentString = Math.round(dayProgress * 100) + "%";
    }

    Rectangle {
        anchors.fill: parent
        color: cardColor
        radius: Appearance.rounding.normal

        Column {
            id: contentColumn
            anchors {
                fill: parent
                margins: cardPadding
            }
            spacing: 14

            Text {
                text: "DAY PROGRESS"
                color: onCardColor
                font {
                    family: "VT323"
                    pixelSize: 32
                    letterSpacing: 4
                }
                anchors.horizontalCenter: parent.horizontalCenter
            }

            RowLayout {
                width: parent.width
                spacing: 0

                Text {
                    text: "ELAPSED: " + root.timeString
                    color: onCardColor
                    font {
                        family: "JetBrains Mono NF"
                        pixelSize: 12
                        letterSpacing: 1
                    }
                    opacity: 0.8
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "LEFT: " + root.remainingString
                    color: onCardColor
                    font {
                        family: "JetBrains Mono NF"
                        pixelSize: 12
                        letterSpacing: 1
                    }
                    opacity: 0.8
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 1

                Repeater {
                    model: root.blockCount
                    delegate: Rectangle {
                        width: 4
                        height: 14
                        radius: 0.5
                        color: index < root.filledBlocks ? accentColor : dimBlockColor
                    }
                }
            }

            RowLayout {
                width: parent.width
                spacing: 0

                Text {
                    text: root.percentString + " OF DAY USED"
                    color: onCardColor
                    font {
                        family: "JetBrains Mono NF"
                        pixelSize: 11
                        letterSpacing: 1
                    }
                    opacity: 0.6
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: root.remainingString + " REMAINING"
                    color: onCardColor
                    font {
                        family: "JetBrains Mono NF"
                        pixelSize: 11
                        letterSpacing: 1
                    }
                    opacity: 0.6
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }
}
