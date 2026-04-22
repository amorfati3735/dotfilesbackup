pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    property var filePath: Directories.todoPath.replace("todo.json", "sticky-notes.json")
    property var notes: []
    property var pinnedNotes: []

    function _rebuildPinned() {
        root.pinnedNotes = root.notes.filter(n => n.pinned);
    }

    function _commit() {
        root.notes = root.notes.slice(0);
        _rebuildPinned();
        save();
    }

    function addNote(text) {
        if (!text || text.trim() === "") return;
        root.notes.push({
            content: text.trim(),
            timestamp: Date.now(),
            pinned: false,
        });
        _commit();
    }

    function removeNote(index) {
        if (index >= 0 && index < root.notes.length) {
            root.notes.splice(index, 1);
            _commit();
        }
    }

    function updateNote(index, text) {
        if (index >= 0 && index < root.notes.length) {
            root.notes[index].content = text;
            _commit();
        }
    }

    function pinNote(index) {
        if (index >= 0 && index < root.notes.length) {
            root.notes[index].pinned = true;
            _commit();
        }
    }

    function unpinNote(index) {
        if (index >= 0 && index < root.notes.length) {
            root.notes[index].pinned = false;
            _commit();
        }
    }

    function togglePin(index) {
        if (index >= 0 && index < root.notes.length) {
            root.notes[index].pinned = !root.notes[index].pinned;
            _commit();
        }
    }

    function updateNotePosition(timestamp, x, y) {
        let idx = root.notes.findIndex(n => n.timestamp === timestamp);
        if (idx !== -1) {
            if (root.notes[idx].x === x && root.notes[idx].y === y) return;
            root.notes[idx].x = x;
            root.notes[idx].y = y;
            // Position-only update: save without rebuilding pinned list
            root.notes = root.notes.slice(0);
            save();
        }
    }

    function save() {
        fileView.setText(JSON.stringify(root.notes));
    }

    function refresh() {
        fileView.reload();
    }

    Component.onCompleted: {
        refresh();
    }

    FileView {
        id: fileView
        path: Qt.resolvedUrl(root.filePath)
        onLoaded: {
            root.notes = JSON.parse(fileView.text());
            root._rebuildPinned();
        }
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) {
                root.notes = [];
                fileView.setText(JSON.stringify(root.notes));
            }
        }
    }
}
