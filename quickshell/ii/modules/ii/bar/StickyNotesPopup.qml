import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

LazyLoader {
    id: root
    active: GlobalStates.stickyNotesOpen

    component: PanelWindow {
        id: panelWindow
        visible: true

        anchors {
            top: true
            left: true
            right: true
        }

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:stickynotes"
        WlrLayershell.layer: WlrLayer.Overlay

        color: "transparent"
        implicitHeight: popupBg.implicitHeight + Appearance.sizes.elevationMargin * 2

        margins {
            top: Appearance.sizes.barHeight
            left: (panelWindow.screen.width / 2) - 225
        }

        mask: Region {
            item: popupBg
        }

        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        onVisibleChanged: {
            if (visible) {
                GlobalFocusGrab.addDismissable(panelWindow);
                newNoteInput.forceActiveFocus();
            } else {
                GlobalFocusGrab.removeDismissable(panelWindow);
            }
        }

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                GlobalStates.stickyNotesOpen = false;
            }
        }

        Keys.onEscapePressed: {
            GlobalStates.stickyNotesOpen = false;
        }

        StyledRectangularShadow {
            target: popupBg
        }

        Rectangle {
            id: popupBg
            width: 450
            implicitHeight: popupContent.implicitHeight + 16 * 2
            radius: Appearance.rounding.small
            color: Appearance.colors.colLayer0
            border.width: 1
            border.color: Appearance.colors.colOutlineVariant

            Shortcut {
                sequence: "Escape"
                onActivated: GlobalStates.stickyNotesOpen = false
            }



            ColumnLayout {
                id: popupContent
                anchors {
                    fill: parent
                    margins: 16
                }
                spacing: 8

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    MaterialSymbol {
                        text: "sticky_note_2"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                    StyledText {
                        text: Translation.tr("Sticky Notes")
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnSurfaceVariant
                        Layout.fillWidth: true
                    }
                    StyledText {
                        visible: StickyNotes.notes.length > 0
                        text: StickyNotes.notes.length
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                        Layout.rightMargin: 10
                    }
                    RippleButton {
                        implicitWidth: 28
                        implicitHeight: 28
                        buttonRadius: Appearance.rounding.full
                        onClicked: GlobalStates.stickyNotesOpen = false
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "close"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                    }
                }

                // Add new note input
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: newNoteInput.implicitHeight + 12
                        color: Appearance.colors.colLayer1
                        radius: Appearance.rounding.small
                        border.width: newNoteInput.activeFocus ? 2 : 1
                        border.color: newNoteInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant

                        TextInput {
                            id: newNoteInput
                            anchors {
                                fill: parent
                                margins: 6
                            }
                            color: Appearance.colors.colOnLayer1
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.family: Appearance.font.family.main
                            clip: true
                            selectByMouse: true

                            Text {
                                anchors.fill: parent
                                visible: !newNoteInput.text
                                text: Translation.tr("New note...")
                                color: Appearance.colors.colSubtext
                                font: newNoteInput.font
                            }

                            Keys.onReturnPressed: {
                                if (newNoteInput.text.trim() !== "") {
                                    StickyNotes.addNote(newNoteInput.text);
                                    newNoteInput.text = "";
                                }
                            }
                        }
                    }

                    RippleButton {
                        implicitWidth: 28
                        implicitHeight: 28
                        buttonRadius: Appearance.rounding.full
                        onClicked: {
                            if (newNoteInput.text.trim() !== "") {
                                StickyNotes.addNote(newNoteInput.text);
                                newNoteInput.text = "";
                            }
                        }
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "add"
                            iconSize: Appearance.font.pixelSize.large
                            color: Appearance.colors.colPrimary
                        }
                    }
                }

                // Separator
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Appearance.colors.colOutlineVariant
                }

                // Widget Controls
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    StyledText {
                        text: Translation.tr("Background Widgets")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colSubtext
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 4

                    Repeater {
                        model: [
                            { name: "todo", icon: "checklist" },
                            { name: "weather", icon: "partly_cloudy_day" },
                            { name: "media", icon: "music_note" },
                            { name: "images", icon: "image" },
                            { name: "clock", icon: "schedule" },
                            { name: "focus", icon: "timer" },
                            { name: "countdown", icon: "event" }
                        ]
                        delegate: RippleButton {
                            implicitWidth: 28
                            implicitHeight: 28
                            buttonRadius: Appearance.rounding.small
                            
                            readonly property bool isEnabled: Config.options.background.widgets[modelData.name].enable
                            
                            Rectangle {
                                anchors.fill: parent
                                radius: Appearance.rounding.small
                                color: isEnabled ? Appearance.colors.colPrimaryContainer : "transparent"
                                border.width: isEnabled ? 0 : 1
                                border.color: isEnabled ? "transparent" : Appearance.colors.colOutlineVariant
                            }
                            
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: modelData.icon
                                iconSize: Appearance.font.pixelSize.normal
                                color: isEnabled ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurfaceVariant
                            }
                            
                            onClicked: {
                                Config.setNestedValue("background.widgets." + modelData.name + ".enable", !isEnabled)
                            }
                        }
                    }

                    // Folder button
                    RippleButton {
                        implicitWidth: 28
                        implicitHeight: 28
                        buttonRadius: Appearance.rounding.small
                        
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "folder_open"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                        
                        onClicked: {
                            openWidgetsFolderProc.running = true
                        }

                        Process {
                            id: openWidgetsFolderProc
                            command: ["dolphin", "--new-window", Config.options.background.widgets.images.directory]
                        }
                    }
                    } // Flow
                } // ColumnLayout (Widget Controls)

                // Countdown Settings (collapsible)
                ColumnLayout {
                    id: countdownSection
                    Layout.fillWidth: true
                    spacing: 0
                    visible: Config.options.background.widgets.countdown.enable

                    property bool expanded: false

                    RippleButton {
                        Layout.fillWidth: true
                        implicitHeight: 30
                        buttonRadius: Appearance.rounding.small

                        onClicked: countdownSection.expanded = !countdownSection.expanded

                        contentItem: RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 4
                            anchors.rightMargin: 4
                            spacing: 4

                            MaterialSymbol {
                                text: "event"
                                iconSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                            }
                            StyledText {
                                text: Config.options.background.widgets.countdown.label || Translation.tr("Countdown")
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colSubtext
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                visible: {
                                    let tgt = new Date(Config.options.background.widgets.countdown.targetDate)
                                    let left = Math.max(0, Math.ceil((tgt - new Date()) / 86400000))
                                    return left > 0
                                }
                                implicitWidth: countdownStatusText.implicitWidth + 12
                                implicitHeight: 18
                                radius: 9
                                color: Appearance.colors.colPrimaryContainer

                                StyledText {
                                    id: countdownStatusText
                                    anchors.centerIn: parent
                                    text: {
                                        let tgt = new Date(Config.options.background.widgets.countdown.targetDate)
                                        let left = Math.max(0, Math.ceil((tgt - new Date()) / 86400000))
                                        return left + "d left"
                                    }
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnPrimaryContainer
                                }
                            }

                            MaterialSymbol {
                                text: countdownSection.expanded ? "expand_less" : "expand_more"
                                iconSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: countdownSection.expanded
                        Layout.topMargin: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            StyledText {
                                text: Translation.tr("Label")
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                                Layout.preferredWidth: 55
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: countdownLabelInput.implicitHeight + 12
                                color: Appearance.colors.colLayer1
                                radius: Appearance.rounding.small
                                border.width: countdownLabelInput.activeFocus ? 2 : 1
                                border.color: countdownLabelInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant

                                TextInput {
                                    id: countdownLabelInput
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    color: Appearance.colors.colOnLayer1
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    font.family: Appearance.font.family.main
                                    clip: true
                                    selectByMouse: true
                                    
                                    Component.onCompleted: text = Config.options.background.widgets.countdown.label

                                    onEditingFinished: {
                                        Config.setNestedValue("background.widgets.countdown.label", text)
                                    }

                                    Text {
                                        anchors.fill: parent
                                        visible: !countdownLabelInput.text
                                        text: Translation.tr("Countdown")
                                        color: Appearance.colors.colSubtext
                                        font: countdownLabelInput.font
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            StyledText {
                                text: Translation.tr("Start")
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                                Layout.preferredWidth: 55
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: countdownStartInput.implicitHeight + 12
                                color: Appearance.colors.colLayer1
                                radius: Appearance.rounding.small
                                border.width: countdownStartInput.activeFocus ? 2 : 1
                                border.color: countdownStartInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant

                                TextInput {
                                    id: countdownStartInput
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    color: Appearance.colors.colOnLayer1
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    font.family: Appearance.font.family.monospace
                                    clip: true
                                    selectByMouse: true
                                    
                                    Component.onCompleted: text = Config.options.background.widgets.countdown.startDate

                                    onEditingFinished: {
                                        if (/^\d{4}-\d{2}-\d{2}$/.test(text)) {
                                            Config.setNestedValue("background.widgets.countdown.startDate", text)
                                        }
                                    }

                                    Text {
                                        anchors.fill: parent
                                        visible: !countdownStartInput.text
                                        text: "YYYY-MM-DD"
                                        color: Appearance.colors.colSubtext
                                        font: countdownStartInput.font
                                    }
                                }
                            }

                            RippleButton {
                                implicitWidth: 26
                                implicitHeight: 26
                                buttonRadius: Appearance.rounding.small
                                colBackground: Appearance.colors.colLayer1
                                colBackgroundHover: Appearance.colors.colLayer1Hover

                                onClicked: {
                                    let today = new Date()
                                    let iso = today.getFullYear() + "-" + String(today.getMonth() + 1).padStart(2, '0') + "-" + String(today.getDate()).padStart(2, '0')
                                    countdownStartInput.text = iso
                                    Config.setNestedValue("background.widgets.countdown.startDate", iso)
                                }

                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "today"
                                    iconSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colSubtext
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            StyledText {
                                text: Translation.tr("Target")
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                                Layout.preferredWidth: 55
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: countdownTargetInput.implicitHeight + 12
                                color: Appearance.colors.colLayer1
                                radius: Appearance.rounding.small
                                border.width: countdownTargetInput.activeFocus ? 2 : 1
                                border.color: countdownTargetInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant

                                TextInput {
                                    id: countdownTargetInput
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    color: Appearance.colors.colOnLayer1
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    font.family: Appearance.font.family.monospace
                                    clip: true
                                    selectByMouse: true
                                    
                                    Component.onCompleted: text = Config.options.background.widgets.countdown.targetDate

                                    onEditingFinished: {
                                        if (/^\d{4}-\d{2}-\d{2}$/.test(text)) {
                                            Config.setNestedValue("background.widgets.countdown.targetDate", text)
                                        }
                                    }

                                    Text {
                                        anchors.fill: parent
                                        visible: !countdownTargetInput.text
                                        text: "YYYY-MM-DD"
                                        color: Appearance.colors.colSubtext
                                        font: countdownTargetInput.font
                                    }
                                }
                            }

                            Item { implicitWidth: 26 }
                        }
                    }
                }

                // Focus Timer Inputs
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    visible: Config.options.background.widgets.focus.enable

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: focusTask.implicitHeight + 12
                        color: Appearance.colors.colLayer1
                        radius: Appearance.rounding.small
                        border.width: focusTask.activeFocus ? 2 : 1
                        border.color: focusTask.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant

                        TextInput {
                            id: focusTask
                            anchors.fill: parent
                            anchors.margins: 6
                            color: Appearance.colors.colOnLayer1
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.family: Appearance.font.family.main
                            clip: true
                            selectByMouse: true

                            Text {
                                anchors.fill: parent
                                visible: !focusTask.text
                                text: Translation.tr("Task name...")
                                color: Appearance.colors.colSubtext
                                font: focusTask.font
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 45
                        implicitHeight: focusMins.implicitHeight + 12
                        color: Appearance.colors.colLayer1
                        radius: Appearance.rounding.small
                        border.width: focusMins.activeFocus ? 2 : 1
                        border.color: focusMins.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant

                        TextInput {
                            id: focusMins
                            anchors.fill: parent
                            anchors.margins: 6
                            color: Appearance.colors.colOnLayer1
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.family: Appearance.font.family.main
                            horizontalAlignment: TextInput.AlignHCenter
                            clip: true
                            selectByMouse: true
                            validator: IntValidator { bottom: 1; top: 999 }

                            Text {
                                anchors.fill: parent
                                visible: !focusMins.text
                                text: Translation.tr("min")
                                horizontalAlignment: Text.AlignHCenter
                                color: Appearance.colors.colSubtext
                                font: focusMins.font
                            }
                        }
                    }

                    RippleButton {
                        implicitWidth: focusTask.implicitHeight + 12
                        implicitHeight: focusTask.implicitHeight + 12
                        buttonRadius: Appearance.rounding.small
                        colBackground: Appearance.colors.colSecondaryContainer
                        colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                        colRipple: Appearance.colors.colSecondaryContainerActive
                        
                        onClicked: {
                            let mins = parseInt(focusMins.text)
                            let task = focusTask.text.trim() || "Untitled"
                            if (!isNaN(mins) && mins > 0) {
                                let presets = Config.options.background.widgets.focus.presets
                                presets.push({ "task": task, "mins": mins })
                                Config.options.background.widgets.focus.presets = presets
                                focusTask.text = ""
                                focusMins.text = ""
                            }
                        }
                        
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "push_pin"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnSecondaryContainer
                        }
                    }

                    RippleButton {
                        implicitWidth: focusTask.implicitHeight + 12
                        implicitHeight: focusTask.implicitHeight + 12
                        buttonRadius: Appearance.rounding.small
                        colBackground: Appearance.colors.colPrimary
                        colBackgroundHover: Appearance.colors.colPrimaryHover
                        colRipple: Appearance.colors.colPrimaryActive
                        
                        onClicked: {
                            let mins = parseInt(focusMins.text)
                            if (!isNaN(mins) && mins > 0) {
                                GlobalStates.focusTaskBuffer = focusTask.text.trim() || "Untitled"
                                GlobalStates.focusMinutesBuffer = mins
                                GlobalStates.focusTrigger++
                                focusTask.text = ""
                                focusMins.text = ""
                                GlobalStates.stickyNotesOpen = false
                            }
                        }
                        
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "play_arrow"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnPrimary
                        }
                    }
                }

                // Focus Timer Presets
                ListView {
                    id: presetsList
                    visible: Config.options.background.widgets.focus.enable && count > 0
                    Layout.fillWidth: true
                    implicitHeight: contentHeight
                    model: Config.options.background.widgets.focus.presets
                    spacing: 4
                    clip: true
                    interactive: false

                    delegate: Rectangle {
                        id: presetDelegate
                        required property var modelData
                        required property int index
                        width: presetsList.width
                        implicitHeight: 32
                        radius: Appearance.rounding.small
                        color: presetHover.hovered ? Appearance.colors.colLayer1Hover : Appearance.colors.colLayer1
                        border.width: 1
                        border.color: Appearance.colors.colOutlineVariant

                        HoverHandler {
                            id: presetHover
                        }

                        RowLayout {
                            anchors {
                                fill: parent
                                margins: 4
                                leftMargin: 8
                            }
                            spacing: 8

                            MaterialSymbol {
                                text: "task_alt"
                                iconSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnLayer1
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: presetDelegate.modelData.task
                                color: Appearance.colors.colOnLayer1
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }

                            StyledText {
                                text: presetDelegate.modelData.mins + "m"
                                color: Appearance.colors.colOnLayer1
                                font.pixelSize: Appearance.font.pixelSize.small
                                verticalAlignment: Text.AlignVCenter
                            }

                            RippleButton {
                                implicitWidth: 24
                                implicitHeight: 24
                                buttonRadius: Appearance.rounding.small
                                onClicked: {
                                    GlobalStates.focusTaskBuffer = presetDelegate.modelData.task
                                    GlobalStates.focusMinutesBuffer = presetDelegate.modelData.mins
                                    GlobalStates.focusTrigger++
                                    GlobalStates.stickyNotesOpen = false
                                }
                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "play_arrow"
                                    iconSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colOnLayer1
                                }
                            }
                            
                            RippleButton {
                                implicitWidth: 24
                                implicitHeight: 24
                                buttonRadius: Appearance.rounding.small
                                opacity: presetHover.hovered ? 1 : 0
                                visible: opacity > 0
                                onClicked: {
                                    let presets = Config.options.background.widgets.focus.presets
                                    presets.splice(presetDelegate.index, 1)
                                    Config.options.background.widgets.focus.presets = presets
                                }
                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "close"
                                    iconSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colError
                                }
                            }
                        }
                    }
                }

                // Separator
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Appearance.colors.colOutlineVariant
                    visible: notesList.count > 0
                }

                // Notes list
                ListView {
                    id: notesList
                    Layout.fillWidth: true
                    implicitHeight: Math.min(contentHeight, 300)
                    model: StickyNotes.notes
                    spacing: 6
                    clip: true
                    interactive: contentHeight > 300

                    delegate: Rectangle {
                        id: noteDelegate
                        required property var modelData
                        required property int index
                        width: notesList.width
                        implicitHeight: noteLayout.implicitHeight + 16
                        radius: Appearance.rounding.small
                        color: noteHover.hovered ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colSecondaryContainer

                        Behavior on color {
                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                        }

                        HoverHandler {
                            id: noteHover
                        }

                        RowLayout {
                            id: noteLayout
                            anchors {
                                fill: parent
                                margins: 8
                            }
                            spacing: 8

                            Rectangle {
                                Layout.fillHeight: true
                                implicitWidth: 3
                                radius: 2
                                color: Appearance.colors.colPrimary
                            }

                            StyledText {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                text: noteDelegate.modelData.content
                                wrapMode: Text.Wrap
                                color: Appearance.colors.colOnSecondaryContainer
                                font.pixelSize: Appearance.font.pixelSize.small
                                verticalAlignment: Text.AlignVCenter
                            }

                            RippleButton {
                                implicitWidth: 22
                                implicitHeight: 22
                                buttonRadius: Appearance.rounding.full
                                opacity: (noteHover.hovered || noteDelegate.modelData.pinned) ? 1 : 0
                                visible: opacity > 0

                                Behavior on opacity {
                                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                                }

                                onClicked: StickyNotes.togglePin(noteDelegate.index)

                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "push_pin"
                                    fill: noteDelegate.modelData.pinned ? 1 : 0
                                    iconSize: Appearance.font.pixelSize.normal
                                    color: noteDelegate.modelData.pinned ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                                }
                            }

                            RippleButton {
                                implicitWidth: 22
                                implicitHeight: 22
                                buttonRadius: Appearance.rounding.full
                                opacity: noteHover.hovered ? 1 : 0
                                visible: opacity > 0

                                Behavior on opacity {
                                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                                }

                                onClicked: StickyNotes.removeNote(noteDelegate.index)

                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "close"
                                    iconSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colSubtext
                                }
                            }
                        }
                    }
                }

                // Empty state
                StyledText {
                    visible: notesList.count === 0
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Translation.tr("No notes yet")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }
        }
    }
}
