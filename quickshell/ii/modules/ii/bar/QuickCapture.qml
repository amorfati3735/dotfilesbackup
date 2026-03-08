import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

LazyLoader {
    id: captureLoader
    active: GlobalStates.quickCaptureOpen

    component: PanelWindow {
        id: captureWindow
        visible: true

        anchors {
            top: true
            left: true
            right: true
        }

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:quickcapture"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        color: "transparent"
        implicitHeight: captureBg.height + Appearance.sizes.elevationMargin * 2 + topPad

        property real topPad: Math.max(120, captureWindow.screen ? captureWindow.screen.height * 0.25 : 200)

        margins {
            left: captureWindow.screen ? (captureWindow.screen.width / 2) - 220 : 0
        }

        mask: Region {
            item: captureBg
        }

        onVisibleChanged: {
            if (visible) {
                GlobalFocusGrab.addDismissable(captureWindow);
                captureInput.forceActiveFocus();
            } else {
                GlobalFocusGrab.removeDismissable(captureWindow);
            }
        }

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                GlobalStates.quickCaptureOpen = false;
            }
        }

        Keys.onEscapePressed: {
            GlobalStates.quickCaptureOpen = false;
        }

        Process {
            id: jotLogger
            property string noteText: ""
            command: ["bash", "-c",
                "FILE='/mnt/windows/Users/DELL/Dropbox/DropsyncFiles/lesser amygdala/quick-jot.md'; " +
                "STAMP=$(date +'%a %b %d, %I:%M %p'); " +
                "echo \"- **${STAMP}** — $1\" >> \"$FILE\"",
                "bash", jotLogger.noteText
            ]
        }

        StyledRectangularShadow {
            target: captureBg
        }

        Rectangle {
            id: captureBg
            width: 440
            implicitHeight: captureContent.implicitHeight + 40
            y: captureWindow.topPad
            x: Appearance.sizes.elevationMargin

            // E-ink: warm parchment, rounded, thick brown border
            radius: Appearance.rounding.normal
            color: "#E8E4DF"
            border.width: 2.5
            border.color: "#8B7355"

            // Subtle noise texture overlay
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

            Shortcut {
                sequence: "Escape"
                onActivated: GlobalStates.quickCaptureOpen = false
            }

            ColumnLayout {
                id: captureContent
                anchors {
                    fill: parent
                    margins: 20
                }
                spacing: 16

                // Header — e-ink style
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Vertical rule accent
                    Rectangle {
                        Layout.preferredWidth: 2
                        Layout.preferredHeight: 14
                        color: "#1A1A1A"
                    }

                    Text {
                        text: "速記"
                        color: "#1A1A1A"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        font.letterSpacing: 2
                    }

                    Text {
                        text: "CAPTURE"
                        color: "#8A8A8A"
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        font.letterSpacing: 3
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "↵"
                        color: "#CACAC8"
                        font.pixelSize: 14
                    }
                }

                // Divider — thin ink line
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: "#1A1A1A"
                    opacity: 0.15
                }

                // Input — bare, like writing on paper
                TextInput {
                    id: captureInput
                    Layout.fillWidth: true
                    Layout.minimumHeight: 32
                    color: "#1A1A1A"
                    font.pixelSize: 18
                    font.family: Appearance.font.family.main
                    wrapMode: TextInput.Wrap
                    clip: true
                    selectByMouse: true
                    selectionColor: "#1A1A1A"
                    selectedTextColor: "#FAFAF8"

                    Text {
                        anchors.fill: parent
                        visible: !captureInput.text
                        text: "何を書きますか…"
                        color: "#C0C0BE"
                        font: captureInput.font
                    }

                    Keys.onReturnPressed: (event) => {
                        if (captureInput.text.trim() !== "") {
                            StickyNotes.addNote(captureInput.text);
                            jotLogger.noteText = captureInput.text.trim();
                            jotLogger.running = true;
                            captureInput.text = "";
                            GlobalStates.quickCaptureOpen = false;
                        }
                    }
                }

                // Underline for input — like a ruled line
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: "#1A1A1A"
                    opacity: 0.08
                }

                // Recent — faded ink
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    visible: StickyNotes.notes.length > 0

                    Text {
                        text: "最近"
                        color: "#B0B0AE"
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        font.letterSpacing: 2
                    }

                    Repeater {
                        model: {
                            let notes = StickyNotes.notes;
                            return notes.slice(-3).reverse();
                        }

                        Text {
                            required property var modelData
                            Layout.fillWidth: true
                            text: "— " + modelData.content
                            color: "#A0A09E"
                            font.pixelSize: 12
                            font.family: Appearance.font.family.main
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }
                }
            }
        }
    }
}
