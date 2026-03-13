import QtQuick
import Quickshell

import qs.modules.common
import qs.modules.ii.background
import qs.modules.ii.bar
import qs.modules.ii.cheatsheet
import qs.modules.ii.dock
import qs.modules.ii.lock
import qs.modules.ii.mediaControls
import qs.modules.ii.notificationPopup
import qs.modules.ii.onScreenDisplay
import qs.modules.ii.onScreenKeyboard
import qs.modules.ii.overview
import qs.modules.ii.polkit
import qs.modules.ii.regionSelector
import qs.modules.ii.screenCorners
import qs.modules.ii.sessionScreen
import qs.modules.ii.sidebarLeft
import qs.modules.ii.sidebarRight
import qs.modules.ii.overlay
import qs.modules.ii.verticalBar
import qs.modules.ii.wallpaperSelector

Scope {
    id: scope
    property bool delayed: false
    Timer {
        interval: 350
        running: true
        repeat: false
        onTriggered: scope.delayed = true
    }

    PanelLoader {
        extraCondition: !Config.options.bar.vertical
        component: Bar {}
    }

    PanelLoader {
        component: Background {}
    }

    PanelLoader {
        component: Cheatsheet {}
        extraCondition: scope.delayed
    }

    PanelLoader {
        extraCondition: Config.options.dock.enable && scope.delayed
        component: Dock {}
    }

    PanelLoader {
        component: Lock {}
    }

    PanelLoader {
        component: MediaControls {}
        extraCondition: scope.delayed
    }

    PanelLoader {
        component: NotificationPopup {}
    }

    PanelLoader {
        component: OnScreenDisplay {}
    }

    PanelLoader {
        component: OnScreenKeyboard {}
        extraCondition: scope.delayed
    }

    PanelLoader {
        component: Overlay {}
        extraCondition: scope.delayed
    }

    PanelLoader {
        component: Overview {}
        extraCondition: scope.delayed
    }

    PanelLoader {
        component: Polkit {}
    }

    PanelLoader {
        component: RegionSelector {}
        extraCondition: scope.delayed
    }

    PanelLoader {
        component: ScreenCorners {}
    }

    PanelLoader {
        component: SessionScreen {}
    }

    PanelLoader {
        component: SidebarLeft {}
        extraCondition: scope.delayed
    }

    PanelLoader {
        component: SidebarRight {}
        extraCondition: scope.delayed
    }

    PanelLoader {
        extraCondition: Config.options.bar.vertical
        component: VerticalBar {}
    }

    PanelLoader {
        component: WallpaperSelector {}
        extraCondition: scope.delayed
    }
}
