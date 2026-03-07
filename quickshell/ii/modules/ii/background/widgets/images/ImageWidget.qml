import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Item {
    id: root

    required property string imagePath
    required property real imageWidth // used as default base width
    required property real imageHeight // fallback, overridden by aspect ratio
    property real posX: 0
    property real posY: 0

    property string stateFile: FileUtils.trimFileProtocol(Directories.config) + "/quickshell/ii/data/image-widget-state.json"
    property string stateKey: imagePath.split("/").pop()
    property var savedStates: ({})
    property bool stateLoaded: false
    property real minSize: 80
    property real maxSize: 800
    property real resizeStep: 20

    // Natural aspect ratio from loaded image
    property real naturalAspect: sizeProbe.implicitWidth > 0 && sizeProbe.implicitHeight > 0
        ? sizeProbe.implicitWidth / sizeProbe.implicitHeight : 1.0
    property real baseWidth: imageWidth

    x: posX
    y: posY
    width: baseWidth
    height: baseWidth / naturalAspect

    // Hidden image to probe natural dimensions
    Image {
        id: sizeProbe
        source: root.imagePath.startsWith("/") ? ("file://" + root.imagePath) : root.imagePath
        visible: false
        asynchronous: true
        onStatusChanged: {
            if (status === Image.Ready && !root.stateLoaded) {
                // Image loaded, aspect ratio is now known — apply saved or default size
                loadStateProc.load();
            }
        }
    }

    Component.onCompleted: {
        if (sizeProbe.status === Image.Ready) {
            loadStateProc.load();
        }
    }

    // Load saved state from JSON file
    Process {
        id: loadStateProc
        stdout: StdioCollector {
            id: loadCollector
            onStreamFinished: {
                try {
                    root.savedStates = JSON.parse(loadCollector.text.trim());
                    const saved = root.savedStates[root.stateKey];
                    if (saved) {
                        root.x = saved.x ?? root.posX;
                        root.y = saved.y ?? root.posY;
                        root.baseWidth = saved.baseWidth ?? root.imageWidth;
                    }
                } catch (e) {}
                root.stateLoaded = true;
            }
        }
        function load() {
            exec(["bash", "-c", `cat '${root.stateFile}' 2>/dev/null || echo '{}'`]);
        }
    }

    // Save state to JSON file (debounced)
    Timer {
        id: saveDebounce
        interval: 500
        onTriggered: readBeforeSaveProc.load();
    }

    Process {
        id: readBeforeSaveProc
        stdout: StdioCollector {
            id: mergeCollector
            onStreamFinished: {
                try {
                    const existing = JSON.parse(mergeCollector.text.trim());
                    existing[root.stateKey] = {
                        x: root.x,
                        y: root.y,
                        baseWidth: root.baseWidth,
                    };
                    writeStateProc.save(JSON.stringify(existing));
                } catch (e) {}
            }
        }
        function load() {
            exec(["bash", "-c", `cat '${root.stateFile}' 2>/dev/null || echo '{}'`]);
        }
    }

    Process {
        id: writeStateProc
        function save(json) {
            exec(["bash", "-c", "printf '%s' \"$1\" > \"$2\"", "_", json, root.stateFile]);
        }
    }

    function saveState() {
        saveDebounce.restart();
    }

    Behavior on baseWidth {
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
            root.baseWidth = Math.max(root.minSize, Math.min(root.maxSize, root.baseWidth + delta));
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
            source: sizeProbe.source
            fillMode: Image.PreserveAspectCrop
            antialiasing: true
            asynchronous: true
            smooth: true
            sourceSize.width: root.width * 2
            sourceSize.height: root.height * 2
        }
    }
}
