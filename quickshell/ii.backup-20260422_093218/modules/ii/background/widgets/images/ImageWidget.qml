import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.functions as CF
import qs.modules.common.widgets

Item {
    id: root

    required property string imagePath
    required property real imageWidth
    required property real imageHeight
    property real posX: 0
    property real posY: 0

    // Config references
    property var imagesConfig: Config.options.background.widgets.images

    // State file
    property string stateFile: FileUtils.trimFileProtocol(Directories.config) + "/quickshell/ii/data/image-widget-state.json"
    property string stateKey: imagePath.split("/").pop()
    property var savedStates: ({})
    property bool stateLoaded: false

    // Size constraints
    property real minSize: 60
    property real maxSize: 1200
    property real resizeStep: 20

    // Natural aspect ratio from loaded image
    property real naturalAspect: sizeProbe.implicitWidth > 0 && sizeProbe.implicitHeight > 0
        ? sizeProbe.implicitWidth / sizeProbe.implicitHeight : 1.0
    property real baseWidth: imageWidth

    // Per-image customization state (loaded from saved state or config defaults)
    property real imageOpacity: imagesConfig.defaultOpacity
    property real imageRotation: imagesConfig.defaultRotation
    property real borderWidth: imagesConfig.defaultBorderWidth
    property string borderColor: imagesConfig.defaultBorderColor
    property real cornerRadius: imagesConfig.defaultCornerRadius < 0 ? Appearance.rounding.small : imagesConfig.defaultCornerRadius
    property string fitMode: imagesConfig.defaultFitMode  // "cover", "fit", "stretch"
    property bool shadowEnabled: imagesConfig.defaultShadow
    property bool locked: false  // position lock

    // Context menu state
    property bool contextMenuVisible: false
    property real contextMenuX: 0
    property real contextMenuY: 0


    x: posX
    y: posY
    width: baseWidth
    height: baseWidth / naturalAspect
    z: contextMenuVisible ? 999 : 0

    rotation: imageRotation

    Behavior on baseWidth {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }
    Behavior on rotation {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    // Hidden image to probe natural dimensions
    Image {
        id: sizeProbe
        source: root.imagePath.startsWith("/") ? ("file://" + root.imagePath) : root.imagePath
        visible: false
        asynchronous: true
        onStatusChanged: {
            if (status === Image.Ready && !root.stateLoaded) {
                loadStateProc.load();
            }
        }
    }

    Component.onCompleted: {
        if (sizeProbe.status === Image.Ready) {
            loadStateProc.load();
        }
    }

    // ── State persistence ──────────────────────────────────────────────

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
                        root.imageOpacity = saved.opacity ?? root.imagesConfig.defaultOpacity;
                        root.imageRotation = saved.rotation ?? root.imagesConfig.defaultRotation;
                        root.borderWidth = saved.borderWidth ?? root.imagesConfig.defaultBorderWidth;
                        root.borderColor = saved.borderColor ?? root.imagesConfig.defaultBorderColor;
                        root.cornerRadius = saved.cornerRadius ?? (root.imagesConfig.defaultCornerRadius < 0 ? Appearance.rounding.small : root.imagesConfig.defaultCornerRadius);
                        root.fitMode = saved.fitMode ?? root.imagesConfig.defaultFitMode;
                        root.shadowEnabled = saved.shadowEnabled !== undefined ? saved.shadowEnabled : root.imagesConfig.defaultShadow;
                        root.locked = saved.locked ?? false;
                    }
                } catch (e) {}
                root.stateLoaded = true;
            }
        }
        function load() {
            exec(["bash", "-c", `cat '${root.stateFile}' 2>/dev/null || echo '{}'`]);
        }
    }

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
                        opacity: root.imageOpacity,
                        rotation: root.imageRotation,
                        borderWidth: root.borderWidth,
                        borderColor: root.borderColor,
                        cornerRadius: root.cornerRadius,
                        fitMode: root.fitMode,
                        shadowEnabled: root.shadowEnabled,
                        locked: root.locked,
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

    // ── Size tooltip on scroll ─────────────────────────────────────────

    Rectangle {
        id: sizeTooltip
        visible: false
        width: sizeTooltipText.implicitWidth + 16
        height: sizeTooltipText.implicitHeight + 8
        radius: Appearance.rounding.verysmall
        color: CF.ColorUtils.transparentize(Appearance.colors.colLayer0, 0.15)
        border.width: 1
        border.color: CF.ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.15)
        anchors.horizontalCenter: parent.horizontalCenter
        y: -height - 8
        z: 100

        StyledText {
            id: sizeTooltipText
            anchors.centerIn: parent
            text: Math.round(root.baseWidth) + " × " + Math.round(root.baseWidth / root.naturalAspect)
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer0
        }

        Timer {
            id: sizeTooltipHideTimer
            interval: 1200
            onTriggered: sizeTooltip.visible = false
        }
    }

    // ── Lock indicator ─────────────────────────────────────────────────

    Rectangle {
        visible: root.locked
        width: 24
        height: 24
        radius: 12
        color: CF.ColorUtils.transparentize(Appearance.colors.colLayer0, 0.2)
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 6
        z: 50

        MaterialSymbol {
            anchors.centerIn: parent
            text: "lock"
            iconSize: 14
            color: Appearance.colors.colOnLayer0
        }
    }

    // ── Drag + scroll interaction ──────────────────────────────────────

    MouseArea {
        id: dragArea
        anchors.fill: parent
        drag.target: root.locked ? undefined : root
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: {
            if (root.locked) return Qt.ArrowCursor;
            return containsPress ? Qt.ClosedHandCursor : Qt.OpenHandCursor;
        }

        onReleased: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                root.saveState();
            }
        }

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                root.contextMenuX = mouse.x;
                root.contextMenuY = mouse.y;
                root.contextMenuVisible = !root.contextMenuVisible;
            }
        }

        onDoubleClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                root.baseWidth = root.imageWidth;
                root.saveState();
            }
        }

        onWheel: (wheel) => {
            const delta = wheel.angleDelta.y > 0 ? root.resizeStep : -root.resizeStep;
            root.baseWidth = Math.max(root.minSize, Math.min(root.maxSize, root.baseWidth + delta));
            root.saveState();
            sizeTooltip.visible = true;
            sizeTooltipHideTimer.restart();
        }
    }

    // ── Shadow ─────────────────────────────────────────────────────────

    StyledRectangularShadow {
        target: imageContainer
        visible: root.shadowEnabled
        opacity: root.imageOpacity
    }

    // ── Loading shimmer ────────────────────────────────────────────────

    Rectangle {
        id: loadingPlaceholder
        anchors.fill: parent
        radius: root.cornerRadius
        visible: sizeProbe.status === Image.Loading
        color: CF.ColorUtils.transparentize(Appearance.colors.colSurfaceContainerHighest, 0.5)

        Rectangle {
            id: shimmer
            width: parent.width * 0.4
            height: parent.height
            radius: parent.radius
            color: CF.ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.05)
            opacity: 0.5

            SequentialAnimation on x {
                loops: Animation.Infinite
                running: loadingPlaceholder.visible
                NumberAnimation {
                    from: -shimmer.width
                    to: loadingPlaceholder.width
                    duration: 1200
                    easing.type: Easing.InOutQuad
                }
                PauseAnimation { duration: 400 }
            }
        }

        clip: true
    }

    // ── Error state ────────────────────────────────────────────────────

    Rectangle {
        id: errorPlaceholder
        anchors.fill: parent
        radius: root.cornerRadius
        visible: sizeProbe.status === Image.Error
        color: CF.ColorUtils.transparentize(Appearance.colors.colErrorContainer, 0.3)

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 6

            MaterialSymbol {
                text: "broken_image"
                iconSize: 32
                color: Appearance.colors.colError
                Layout.alignment: Qt.AlignHCenter
            }

            StyledText {
                text: root.stateKey
                font.pixelSize: Appearance.font.pixelSize.small
                color: CF.ColorUtils.transparentize(Appearance.colors.colOnErrorContainer, 0.7)
                elide: Text.ElideMiddle
                Layout.maximumWidth: root.width - 20
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    // ── Main image container ───────────────────────────────────────────

    Rectangle {
        id: imageContainer
        anchors.fill: parent
        radius: root.cornerRadius
        color: "transparent"
        opacity: root.imageOpacity

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
        border.width: root.borderWidth
        border.color: root.borderColor
        visible: sizeProbe.status !== Image.Error

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
            anchors.margins: root.borderWidth
            source: sizeProbe.source
            fillMode: {
                if (root.fitMode === "fit") return Image.PreserveAspectFit;
                if (root.fitMode === "stretch") return Image.Stretch;
                return Image.PreserveAspectCrop; // "cover"
            }
            antialiasing: true
            asynchronous: true
            smooth: true
            sourceSize.width: root.width * 2
            sourceSize.height: root.height * 2
        }
    }

    // ── Context menu ───────────────────────────────────────────────────

    Rectangle {
        id: contextMenu
        visible: root.contextMenuVisible
        x: Math.min(root.contextMenuX, root.width - width - 4)
        y: Math.min(root.contextMenuY, root.height - height - 4)
        width: 200
        height: menuColumn.implicitHeight + 16
        radius: Appearance.rounding.small
        color: CF.ColorUtils.applyAlpha(Appearance.colors.colLayer1, 1)
        border.width: 1
        border.color: CF.ColorUtils.transparentize(Appearance.colors.colOutline, 0.3)
        z: 999

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.35)
            shadowBlur: 0.6
            shadowVerticalOffset: 4
        }

        // Close when clicking outside
        MouseArea {
            id: contextMenuDismissArea
            parent: root.parent
            anchors.fill: parent
            visible: root.contextMenuVisible
            z: 998
            onClicked: root.contextMenuVisible = false
        }

        ColumnLayout {
            id: menuColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            spacing: 2

            // ── Section: Size ──
            StyledText {
                text: "SIZE"
                font.pixelSize: Appearance.font.pixelSize.small - 2
                font.weight: Font.Bold
                color: CF.ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.5)
                Layout.leftMargin: 4
                Layout.topMargin: 2
                font.letterSpacing: 1.2
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: [
                        { label: "S", size: 120 },
                        { label: "M", size: 240 },
                        { label: "L", size: 400 },
                        { label: "XL", size: 600 }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 28
                        radius: Appearance.rounding.verysmall
                        color: Math.abs(root.baseWidth - modelData.size) < 20
                            ? CF.ColorUtils.transparentize(Appearance.colors.colPrimary, 0.3)
                            : sizeButtonArea.containsMouse
                                ? CF.ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.08)
                                : "transparent"

                        StyledText {
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                            color: Math.abs(root.baseWidth - modelData.size) < 20
                                ? Appearance.colors.colPrimary
                                : Appearance.colors.colOnLayer1
                        }

                        MouseArea {
                            id: sizeButtonArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.baseWidth = modelData.size;
                                root.saveState();
                            }
                        }
                    }
                }
            }

            // ── Divider ──
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: CF.ColorUtils.transparentize(Appearance.colors.colOutline, 0.15)
                Layout.topMargin: 4
                Layout.bottomMargin: 4
            }

            // ── Section: Display ──
            StyledText {
                text: "DISPLAY"
                font.pixelSize: Appearance.font.pixelSize.small - 2
                font.weight: Font.Bold
                color: CF.ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.5)
                Layout.leftMargin: 4
                font.letterSpacing: 1.2
            }

            // Fit mode
            ContextMenuItem {
                icon: "aspect_ratio"
                label: "Fit: " + root.fitMode.charAt(0).toUpperCase() + root.fitMode.slice(1)
                onMenuClicked: {
                    const modes = ["cover", "fit", "stretch"];
                    const idx = (modes.indexOf(root.fitMode) + 1) % modes.length;
                    root.fitMode = modes[idx];
                    root.saveState();
                }
            }

            // Opacity
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                spacing: 8

                MaterialSymbol {
                    text: "opacity"
                    iconSize: 16
                    color: Appearance.colors.colOnLayer1
                }

                StyledText {
                    text: Math.round(root.imageOpacity * 100) + "%"
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                    Layout.preferredWidth: 34
                }

                // Decrease opacity
                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: Appearance.rounding.verysmall
                    color: opDecArea.containsMouse ? CF.ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.08) : "transparent"
                    StyledText {
                        anchors.centerIn: parent
                        text: "−"
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer1
                    }
                    MouseArea {
                        id: opDecArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            root.imageOpacity = Math.max(0.1, root.imageOpacity - 0.1);
                            root.saveState();
                        }
                    }
                }

                // Increase opacity
                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: Appearance.rounding.verysmall
                    color: opIncArea.containsMouse ? CF.ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.08) : "transparent"
                    StyledText {
                        anchors.centerIn: parent
                        text: "+"
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer1
                    }
                    MouseArea {
                        id: opIncArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            root.imageOpacity = Math.min(1.0, root.imageOpacity + 0.1);
                            root.saveState();
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // Rotation
            ContextMenuItem {
                icon: "rotate_right"
                label: "Rotate " + root.imageRotation + "°"
                onMenuClicked: {
                    root.imageRotation = (root.imageRotation + 90) % 360;
                    root.saveState();
                }
            }

            // ── Divider ──
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: CF.ColorUtils.transparentize(Appearance.colors.colOutline, 0.15)
                Layout.topMargin: 4
                Layout.bottomMargin: 4
            }

            // ── Section: Toggles ──
            StyledText {
                text: "OPTIONS"
                font.pixelSize: Appearance.font.pixelSize.small - 2
                font.weight: Font.Bold
                color: CF.ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.5)
                Layout.leftMargin: 4
                font.letterSpacing: 1.2
            }

            ContextMenuItem {
                icon: root.borderWidth > 0 ? "border_style" : "border_clear"
                label: root.borderWidth > 0 ? "Border: On" : "Border: Off"
                onMenuClicked: {
                    root.borderWidth = root.borderWidth > 0 ? 0 : 2;
                    root.saveState();
                }
            }

            ContextMenuItem {
                icon: root.shadowEnabled ? "shadow" : "hide_source"
                label: root.shadowEnabled ? "Shadow: On" : "Shadow: Off"
                onMenuClicked: {
                    root.shadowEnabled = !root.shadowEnabled;
                    root.saveState();
                }
            }

            ContextMenuItem {
                icon: root.locked ? "lock" : "lock_open"
                label: root.locked ? "Locked" : "Unlocked"
                onMenuClicked: {
                    root.locked = !root.locked;
                    root.saveState();
                }
            }
        }
    }

    // ── ContextMenuItem component ──────────────────────────────────────

    component ContextMenuItem: Rectangle {
        id: menuItem
        property string icon: ""
        property string label: ""
        property color textColor: Appearance.colors.colOnLayer1
        signal menuClicked()

        Layout.fillWidth: true
        implicitHeight: 30
        radius: Appearance.rounding.verysmall
        color: menuItemArea.containsMouse
            ? CF.ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.08)
            : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            spacing: 8

            MaterialSymbol {
                text: menuItem.icon
                iconSize: 16
                color: menuItem.textColor
            }

            StyledText {
                text: menuItem.label
                font.pixelSize: Appearance.font.pixelSize.small
                color: menuItem.textColor
                Layout.fillWidth: true
            }
        }

        MouseArea {
            id: menuItemArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: menuItem.menuClicked()
        }
    }
}
