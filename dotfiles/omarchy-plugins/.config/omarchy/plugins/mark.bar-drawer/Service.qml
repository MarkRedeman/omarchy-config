import QtQuick

// Headless companion for mark.bar-drawer.
//
// A bar-widget plugin only receives a scoped PluginBarApi facade, which does
// not expose the host's widget catalogue. A service entry point does receive
// the shell's detached catalogue snapshot, so the drawer can instantiate the
// real widgets from `barWidgetRegistry.widgets` without walking the QML
// parent chain.
QtObject {
  property var barWidgetRegistry: null
}
