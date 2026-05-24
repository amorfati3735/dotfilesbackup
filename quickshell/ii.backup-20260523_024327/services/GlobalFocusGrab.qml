pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland

/**
 * Manages a HyprlandFocusGrab that's to be shared by all windows.
 * "Persistent" is for windows that should always be included but not closed on dismiss, like bar and onscreen keyboard.
 * "Dismissable" is for stuff like sidebars
 */ 
Singleton {
    id: root

    signal dismissed()

    property list<var> persistent: []
    property list<var> dismissable: []

    function dismiss() {
        root.dismissable = [];
        root.dismissed();
    }

    Component.onCompleted: {
        console.log("[GlobalFocusGrab] Initialized");
    }

    function addPersistent(window) {
        if (root.persistent.indexOf(window) === -1) {
            root.persistent.push(window);
        }
    }

    function removePersistent(window) {
        var index = root.persistent.indexOf(window);
        if (index !== -1) {
            root.persistent.splice(index, 1);
        }
    }

    function addDismissable(window) {
        if (root.dismissable.indexOf(window) === -1) {
            root.dismissable.push(window);
        }
    }

    function removeDismissable(window) {
        var index = root.dismissable.indexOf(window);
        if (index !== -1) {
            root.dismissable.splice(index, 1);
        }
    }

    function hasActive(element) {
        return element?.activeFocus || Array.from(
            element?.children
        ).some(
            (child) => hasActive(child)
        );
    }

    HyprlandFocusGrab {
        id: grab
        windows: {
            let isAlive = w => w != null && String(w).indexOf("null") === -1;
            let validDismissable = root.dismissable.filter(isAlive);
            let validPersistent = root.persistent.filter(isAlive);
            if (validDismissable.length === 0) return [];
            let useBoth = validDismissable.every(w => !w?.focusable) || validDismissable.some(w => hasActive(w?.contentItem));
            return useBoth ? [...validDismissable, ...validPersistent] : [...validDismissable];
        }
        active: root.dismissable.filter(w => w != null).length > 0
        onCleared: () => {
            root.dismiss();
        }
    }

}
