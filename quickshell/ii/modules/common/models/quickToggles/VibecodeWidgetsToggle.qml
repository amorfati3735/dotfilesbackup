import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

QuickToggleModel {
    name: Translation.tr("VibeCode Widgets")
    hasStatusText: false

    toggled: GlobalStates.vibecodeWidgetsEnabled
    icon: "science"

    mainAction: () => {
        GlobalStates.vibecodeWidgetsEnabled = !GlobalStates.vibecodeWidgetsEnabled;
    }

    tooltipText: Translation.tr("Enable custom vibecoded desktop widgets")
}
