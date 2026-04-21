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

    readonly property var pinnedNotes: notes.filter(n => n.pinned)

    function addNote(text) {
        if (!text || text.trim() === "") return;
        notes.push({
            content: text.trim(),
            timestamp: Date.now(),
            pinned: false,
        });
        root.notes = notes.slice(0);
        save();
    }

    function removeNote(index) {
        if (index >= 0 && index < notes.length) {
            notes.splice(index, 1);
            root.notes = notes.slice(0);
            save();
        }
    }

    function updateNote(index, text) {
        if (index >= 0 && index < notes.length) {
            notes[index].content = text;
            root.notes = notes.slice(0);
            save();
        }
    }

    function pinNote(index) {
        if (index >= 0 && index < notes.length) {
            notes[index].pinned = true;
            root.notes = notes.slice(0);
            save();
        }
    }

    function unpinNote(index) {
        if (index >= 0 && index < notes.length) {
            notes[index].pinned = false;
            root.notes = notes.slice(0);
            save();
        }
    }

    function togglePin(index) {
        if (index >= 0 && index < notes.length) {
            notes[index].pinned = !notes[index].pinned;
            root.notes = notes.slice(0);
            save();
        }
    }

    function updateNotePosition(timestamp, x, y) {
        let idx = notes.findIndex(n => n.timestamp === timestamp);
        if (idx !== -1) {
            if (notes[idx].x === x && notes[idx].y === y) return;
            notes[idx].x = x;
            notes[idx].y = y;
            root.notes = notes.slice(0);
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
        }
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) {
                root.notes = [];
                fileView.setText(JSON.stringify(root.notes));
            }
        }
    }
}
