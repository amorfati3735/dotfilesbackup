import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

QuickToggleModel {
    name: Translation.tr("Day Progress")
    hasStatusText: false

    toggled: Config.options.background.widgets.dayprogress.enable
    icon: "schedule"

    mainAction: () => {
        Config.options.background.widgets.dayprogress.enable = !Config.options.background.widgets.dayprogress.enable;
    }

    tooltipText: Translation.tr("Show day progress widget")
}
