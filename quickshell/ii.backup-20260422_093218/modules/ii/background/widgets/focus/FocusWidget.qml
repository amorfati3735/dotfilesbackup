import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "focus"

    implicitWidth: 280
    implicitHeight: 160

    property int initialSeconds: 0
    property int secondsValue: 0
    property bool isRunning: false
    property bool sessionLogged: false
    property bool flashState: false

    // Calm, soft palette
    property color bgCol: CF.ColorUtils.applyAlpha(Appearance.colors.colLayer0, 0.95)
    property color mainTextCol: Appearance.colors.colOnLayer0
    property color subTextCol: CF.ColorUtils.applyAlpha(Appearance.colors.colOnLayer0, 0.45)
    property color accentCol: Appearance.m3colors.m3primary
    property color accentOnCol: Appearance.m3colors.m3onPrimary
    property color trackCol: CF.ColorUtils.applyAlpha(Appearance.colors.colOnLayer0, 0.08)

    Connections {
        target: GlobalStates
        function onFocusTriggerChanged() {
            if (GlobalStates.focusTrigger > 0) {
                root.initialSeconds = GlobalStates.focusMinutesBuffer * 60
                root.secondsValue = root.initialSeconds
                root.sessionLogged = false
                taskLabel.text = GlobalStates.focusTaskBuffer
                root.isRunning = true
            }
        }
    }

    Timer {
        id: mainTimer
        interval: 1000
        repeat: true
        running: root.isRunning
        onTriggered: {
            root.secondsValue--
            if (root.secondsValue <= 0) {
                root.isRunning = false
                alarmTimer.start()
            }
        }
    }

    Timer {
        id: alarmTimer
        interval: 500
        repeat: true
        running: false
        onTriggered: {
            root.flashState = !root.flashState
        }
    }

    function playPauseTimer() {
        if (initialSeconds > 0) {
            isRunning = !isRunning
        }
    }

    function resetTimer() {
        isRunning = false
        alarmTimer.stop()
        secondsValue = 0
        initialSeconds = 0
        flashState = false
        taskLabel.text = ""
    }

    Process {
        id: loggerProc
        property string pyExec: "/usr/bin/python3"
        command: [pyExec, "/home/pratik/.config/quickshell/ii/scripts/focus_logger.py", "--task", taskLabel.text, "--mins", String(Math.max(1, Math.floor((root.initialSeconds - root.secondsValue) / 60)))]
        onExited: {
            root.sessionLogged = true
            resetTimer()
        }
    }

    StyledRectangularShadow {
        target: background
    }

    Rectangle {
        id: background
        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin

        radius: Appearance.rounding.normal
        color: root.bgCol
        border.color: CF.ColorUtils.applyAlpha(Appearance.colors.colOnLayer0, 0.06)
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 0

            // Top row: icon + japanese label
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                MaterialSymbol {
                    text: "school"
                    color: root.subTextCol
                    iconSize: 16
                }

                StyledText {
                    text: "集中"  // shūchū — focus
                    color: root.subTextCol
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                Item { Layout.fillWidth: true }

                // Status pill
                Rectangle {
                    visible: root.initialSeconds > 0
                    implicitWidth: statusText.implicitWidth + 12
                    implicitHeight: 18
                    radius: 9
                    color: root.isRunning ? CF.ColorUtils.applyAlpha(root.accentCol, 0.15) : root.trackCol

                    StyledText {
                        id: statusText
                        anchors.centerIn: parent
                        text: root.isRunning ? "進行中" : (root.flashState ? "完了" : "完了")  // shinkochu / kanryo
                        color: root.isRunning ? root.accentCol : root.subTextCol
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }
                }
            }

            Item { Layout.preferredHeight: 8 }

            // Task name
            StyledText {
                id: taskLabel
                Layout.fillWidth: true
                text: ""
                color: root.mainTextCol
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                visible: text !== ""
            }

            // Idle state
            StyledText {
                visible: taskLabel.text === ""
                text: "待機中"  // taikichū — standing by
                color: root.subTextCol
                font.pixelSize: Appearance.font.pixelSize.normal
            }

            Item { Layout.fillHeight: true }

            // Timer + controls row
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Timer digits
                StyledText {
                    id: timerDigits
                    text: {
                        let total = Math.abs(root.secondsValue);
                        let m = Math.floor(total / 60);
                        let s = total % 60;
                        return String(m).padStart(2, '0') + ":" + String(s).padStart(2, '0');
                    }
                    color: root.flashState ? Appearance.colors.colError : root.mainTextCol
                    font.family: Appearance.font.family.numbers
                    font.pixelSize: 42
                    font.weight: Font.Bold
                }

                Item { Layout.fillWidth: true }

                // Controls
                RowLayout {
                    spacing: 6
                    visible: root.initialSeconds > 0

                    // Stop / Log
                    RippleButton {
                        implicitWidth: 32
                        implicitHeight: 32
                        buttonRadius: 16
                        colBackground: root.trackCol
                        colBackgroundHover: CF.ColorUtils.applyAlpha(root.subTextCol, 0.12)
                        colRipple: CF.ColorUtils.applyAlpha(root.subTextCol, 0.2)

                        onClicked: {
                            if (root.initialSeconds > 0 && !root.sessionLogged) {
                                loggerProc.running = true
                            } else {
                                root.resetTimer()
                            }
                        }

                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "stop"
                            color: root.subTextCol
                            iconSize: 18
                        }
                    }

                    // Play / Pause
                    RippleButton {
                        implicitWidth: 36
                        implicitHeight: 36
                        buttonRadius: 18
                        colBackground: root.accentCol
                        colBackgroundHover: root.accentCol
                        colRipple: root.accentOnCol

                        onClicked: root.playPauseTimer()

                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: root.isRunning ? "pause" : "play_arrow"
                            color: root.accentOnCol
                            iconSize: 22
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 8 }

            // Progress track
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 3
                radius: 1.5
                color: root.trackCol

                Rectangle {
                    width: root.initialSeconds > 0 ? parent.width * Math.max(0, root.secondsValue / root.initialSeconds) : 0
                    height: parent.height
                    radius: 1.5
                    color: root.accentCol

                    Behavior on width {
                        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }
}
