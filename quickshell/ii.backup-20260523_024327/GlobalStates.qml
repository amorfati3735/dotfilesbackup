import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    property bool barOpen: true
    property bool crosshairOpen: false
    property bool sidebarLeftOpen: false
    property bool sidebarRightOpen: false
    property bool mediaControlsOpen: false
    property bool osdBrightnessOpen: false
    property bool osdVolumeOpen: false
    property bool oskOpen: false
    property bool overlayOpen: false
    property bool overviewOpen: false
    property bool regionSelectorOpen: false
    property bool searchOpen: false
    property bool stickyNotesOpen: false
    property bool screenLocked: false
    property bool screenLockContainsCharacters: false
    property bool screenUnlockFailed: false
    property bool sessionOpen: false
    property bool superDown: false
    property bool superReleaseMightTrigger: true
    property bool wallpaperSelectorOpen: false
    property bool workspaceShowNumbers: false
    
    // Focus Timer State Buffers (written by StickyNotesPopup, read by FocusWidget)
    property string focusTaskBuffer: ""
    property int focusMinutesBuffer: 0
    property int focusTrigger: 0

    // Quick Capture
    property bool quickCaptureOpen: false

    onSidebarRightOpenChanged: {
        if (GlobalStates.sidebarRightOpen) {
            Notifications.timeoutAll();
            Notifications.markAllRead();
        }
    }

    GlobalShortcut {
        name: "workspaceNumber"
        description: "Hold to show workspace numbers, release to show icons"

        onPressed: {
            root.superDown = true
        }
        onReleased: {
            root.superDown = false
        }
    }

    GlobalShortcut {
        name: "quickCapture"
        description: "Opens quick capture overlay"

        onPressed: {
            root.quickCaptureOpen = !root.quickCaptureOpen
        }
    }

    GlobalShortcut {
        name: "stickyNotes"
        description: "Opens sticky notes popup"

        onPressed: {
            root.stickyNotesOpen = !root.stickyNotesOpen
        }
    }
}