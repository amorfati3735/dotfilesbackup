import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    required property string imagePath
    required property real imageWidth
    required property real imageHeight
    property real posX: 0
    property real posY: 0

    property string stateFile: Directories.config + "/quickshell/ii/data/image-widget-state.json"
    property string stateKey: imagePath.split("/").pop()
    property var savedStates: ({})
    property bool stateLoaded: false
    property real minSize: 80
    property real maxSize: 800
    property real resizeStep: 20

    x: posX
    y: posY
    width: imageWidth
    height: imageHeight

    Component.onCompleted: {
        loadStateProc.running = true;
    }

    // Load saved state from JSON file
    Process {
        id: loadStateProc
        command: ["bash", "-c", `cat '${root.stateFile}' 2>/dev/null || echo '{}'`]
        stdout: StdioCollector {
            id: loadCollector
            onStreamFinished: {
                try {
                    root.savedStates = JSON.parse(loadCollector.text.trim());
                    const saved = root.savedStates[root.stateKey];
                    if (saved) {
                        root.x = saved.x ?? root.posX;
                        root.y = saved.y ?? root.posY;
                        root.width = saved.width ?? root.imageWidth;
                        root.height = saved.height ?? root.imageHeight;
                    }
                } catch (e) {
                    // Invalid JSON, use defaults
                }
                root.stateLoaded = true;
            }
        }
    }

    // Save state to JSON file (debounced)
    Timer {
        id: saveDebounce
        interval: 500
        onTriggered: readBeforeSaveProc.running = true;
    }

    Process {
        id: readBeforeSaveProc
        command: ["bash", "-c", `cat '${root.stateFile}' 2>/dev/null || echo '{}'`]
        stdout: StdioCollector {
            id: mergeCollector
            onStreamFinished: {
                try {
                    const existing = JSON.parse(mergeCollector.text.trim());
                    existing[root.stateKey] = {
                        x: root.x,
                        y: root.y,
                        width: root.width,
                        height: root.height,
                    };
                    writeStateProc.stateJson = JSON.stringify(existing);
                    writeStateProc.running = true;
                } catch (e) {}
            }
        }
    }

    Process {
        id: writeStateProc
        property string stateJson: "{}"
        command: ["bash", "-c", `echo '${stateJson}' > '${root.stateFile}'`]
    }

    function saveState() {
        saveDebounce.restart();
    }

    Behavior on width {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }
    Behavior on height {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        drag.target: root
        acceptedButtons: Qt.LeftButton
        cursorShape: containsPress ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        onReleased: root.saveState()

        onWheel: (wheel) => {
            const delta = wheel.angleDelta.y > 0 ? root.resizeStep : -root.resizeStep;
            const aspect = root.width / root.height;
            const newW = Math.max(root.minSize, Math.min(root.maxSize, root.width + delta));
            const newH = Math.max(root.minSize, Math.min(root.maxSize, newW / aspect));
            root.width = newW;
            root.height = newH;
            root.saveState();
        }
    }

    StyledRectangularShadow {
        target: imageContainer
    }

    Rectangle {
        id: imageContainer
        anchors.fill: parent
        radius: Appearance.rounding.small
        color: "transparent"

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: imageContainer.width
                height: imageContainer.height
                radius: imageContainer.radius
            }
        }

        Image {
            anchors.fill: parent
            source: root.imagePath.startsWith("/") ? ("file://" + root.imagePath) : root.imagePath
            fillMode: Image.PreserveAspectCrop
            antialiasing: true
            asynchronous: true
            smooth: true
            sourceSize.width: root.width * 2
            sourceSize.height: root.height * 2
        }
    }
}
