import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root

    property bool playing: false
    property bool hovered: false

    hoverEnabled: true
    onEntered: root.hovered = true
    onExited: { root.hovered = false; catView.petTimer.stop(); catView.expression = "idle" }
    onClicked: {
        if (playing) {
            playing = false;
            tetrisView.resetGame();
        } else {
            playing = true;
            tetrisView.spawnPiece();
            tetrisView.clearAndRefresh();
        }
    }

    implicitWidth: playing ? tetrisView.implicitWidth : catView.implicitWidth
    implicitHeight: Appearance.sizes.barHeight

    Behavior on implicitWidth {
        NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
    }

    // ──── Cat view ────
    Item {
        id: catView
        anchors.centerIn: parent
        visible: !root.playing
        implicitWidth: catLabel.implicitWidth
        implicitHeight: catLabel.implicitHeight

        property string expression: "idle"

        // Expressions
        readonly property var faces: ({
            "idle":    " /\\_/\\\n( o.o )\n > ^ <",
            "blink":   " /\\_/\\\n( -.- )\n > ^ <",
            "happy":   " /\\_/\\\n( ^.^ )\n > ^ <",
            "pet":     " /\\_/\\\n( >.< )\n > ^ <",
            "sleepy":  " /\\_/\\\n( u.u )\n > ^ <",
        })

        property string currentFace: faces[expression] ?? faces["idle"]

        Timer {
            id: blinkTimer
            interval: 3000 + Math.random() * 4000
            running: !root.playing && catView.expression !== "pet"
            repeat: true
            onTriggered: {
                if (catView.expression === "idle") {
                    catView.expression = "blink";
                    blinkResetTimer.start();
                }
                interval = 3000 + Math.random() * 4000;
            }
        }

        Timer {
            id: blinkResetTimer
            interval: 180
            onTriggered: {
                if (catView.expression === "blink") catView.expression = "idle";
            }
        }

        // Hover → happy face
        states: [
            State {
                name: "hovered"
                when: root.hovered && !root.playing && catView.expression !== "pet"
                PropertyChanges { target: catView; expression: "happy" }
            }
        ]

        onExpressionChanged: {
            if (expression !== "happy" && expression !== "pet" && root.hovered && !root.playing) {
                // Don't override hover expression
            }
        }

        // Pet animation on repeated hovering
        property int petCount: 0
        Timer {
            id: petResetTimer
            interval: 2000
            onTriggered: catView.petCount = 0
        }

        property Timer petTimer: Timer {
            interval: 800
            onTriggered: {
                catView.expression = root.hovered ? "happy" : "idle";
            }
        }

        // Sleepy after idle for a while
        Timer {
            id: sleepyTimer
            interval: 30000
            running: !root.playing && !root.hovered
            repeat: false
            onTriggered: {
                if (!root.hovered && !root.playing) catView.expression = "sleepy";
            }
        }

        Connections {
            target: root
            function onHoveredChanged() {
                if (root.hovered) {
                    sleepyTimer.restart();
                    if (catView.expression === "sleepy") catView.expression = "happy";
                    
                    if (!root.playing) {
                        catView.petCount++;
                        petResetTimer.restart();
                        if (catView.petCount >= 3) {
                            catView.expression = "pet";
                            catView.petTimer.restart();
                            catView.petCount = 0;
                        }
                    }
                }
            }
        }

        Text {
            id: catLabel
            anchors.centerIn: parent
            text: catView.currentFace
            color: Appearance.colors.colOnLayer1
            opacity: 0.75
            font {
                family: Appearance.font.family.monospace
                pixelSize: 7
                letterSpacing: -0.5
            }
            lineHeight: 0.9
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            Behavior on text {
                SequentialAnimation {
                    NumberAnimation { target: catLabel; property: "opacity"; to: 0.3; duration: 80 }
                    PropertyAction { target: catLabel; property: "text" }
                    NumberAnimation { target: catLabel; property: "opacity"; to: 0.75; duration: 120 }
                }
            }
        }
    }

    // ──── Tetris view ────
    Item {
        id: tetrisView
        anchors.centerIn: parent
        visible: root.playing

        readonly property int cols: 4
        readonly property int rows: 5
        readonly property real dotSize: 3.5
        readonly property real dotSpacing: 1.5
        readonly property real cellSize: dotSize + dotSpacing
        readonly property color dotColor: Appearance.m3colors.m3primary

        implicitWidth: cols * cellSize
        implicitHeight: Appearance.sizes.barHeight

        Item {
            anchors.centerIn: parent
            width: tetrisView.cols * tetrisView.cellSize
            height: tetrisView.rows * tetrisView.cellSize

            Repeater {
                id: dotRepeater
                model: tetrisView.cols * tetrisView.rows

                Rectangle {
                    required property int index
                    readonly property int col: index % tetrisView.cols
                    readonly property int row: Math.floor(index / tetrisView.cols)

                    x: col * tetrisView.cellSize
                    y: row * tetrisView.cellSize
                    width: tetrisView.dotSize
                    height: tetrisView.dotSize
                    radius: 1
                    color: tetrisView.dotColor
                    opacity: 0.12

                    Behavior on opacity {
                        NumberAnimation { duration: 400; easing.type: Easing.InOutQuad }
                    }
                }
            }
        }

        readonly property var tetrominoes: [
            [[0,0],[1,0],[0,1],[1,1]],
            [[0,0],[1,0],[2,0],[3,0]],
            [[0,0],[0,1],[0,2],[0,3]],
            [[0,0],[1,0],[2,0],[2,1]],
            [[0,0],[0,1],[0,2],[1,2]],
            [[0,0],[1,0],[2,0],[0,1]],
            [[0,0],[1,0],[1,1],[2,1]],
            [[1,0],[2,0],[0,1],[1,1]],
            [[0,0],[1,0],[2,0],[1,1]],
            [[1,0],[0,1],[1,1],[2,1]],
        ]

        property int activePieceType: 0
        property int activePieceCol: 0
        property int activePieceRow: -4
        property var settledBlocks: []

        function getBlockIndex(c, r) {
            if (c < 0 || c >= cols || r < 0 || r >= rows) return -1;
            return r * cols + c;
        }

        function isSettled(c, r) {
            for (var i = 0; i < settledBlocks.length; i++) {
                if (settledBlocks[i][0] === c && settledBlocks[i][1] === r) return true;
            }
            return false;
        }

        function canPlace(piece, pc, pr) {
            for (var i = 0; i < piece.length; i++) {
                var c = pc + piece[i][0];
                var r = pr + piece[i][1];
                if (c < 0 || c >= cols) return false;
                if (r >= rows) return false;
                if (r >= 0 && isSettled(c, r)) return false;
            }
            return true;
        }

        function clearAndRefresh() {
            for (var i = 0; i < dotRepeater.count; i++)
                dotRepeater.itemAt(i).opacity = 0.12;
            for (var s = 0; s < settledBlocks.length; s++) {
                var idx = getBlockIndex(settledBlocks[s][0], settledBlocks[s][1]);
                if (idx >= 0) dotRepeater.itemAt(idx).opacity = 0.7;
            }
            var piece = tetrominoes[activePieceType];
            for (var j = 0; j < piece.length; j++) {
                var ac = activePieceCol + piece[j][0];
                var ar = activePieceRow + piece[j][1];
                var aidx = getBlockIndex(ac, ar);
                if (aidx >= 0) dotRepeater.itemAt(aidx).opacity = 0.9;
            }
        }

        function clearFullRows() {
            for (var r = rows - 1; r >= 0; r--) {
                var full = true;
                for (var c = 0; c < cols; c++) {
                    if (!isSettled(c, r)) { full = false; break; }
                }
                if (full) {
                    var newSettled = [];
                    for (var i = 0; i < settledBlocks.length; i++) {
                        if (settledBlocks[i][1] < r)
                            newSettled.push([settledBlocks[i][0], settledBlocks[i][1] + 1]);
                        else if (settledBlocks[i][1] > r)
                            newSettled.push(settledBlocks[i]);
                    }
                    settledBlocks = newSettled;
                    r++;
                }
            }
        }

        function spawnPiece() {
            activePieceType = Math.floor(Math.random() * tetrominoes.length);
            var piece = tetrominoes[activePieceType];
            var maxCol = 0;
            for (var i = 0; i < piece.length; i++) {
                if (piece[i][0] > maxCol) maxCol = piece[i][0];
            }
            activePieceCol = Math.floor(Math.random() * (cols - maxCol));
            activePieceRow = -3;
        }

        function resetGame() {
            settledBlocks = [];
            activePieceRow = -4;
            gameTimer.stop();
            for (var i = 0; i < dotRepeater.count; i++)
                dotRepeater.itemAt(i).opacity = 0.12;
        }

        function tick() {
            var piece = tetrominoes[activePieceType];
            if (canPlace(piece, activePieceCol, activePieceRow + 1)) {
                activePieceRow++;
            } else {
                for (var i = 0; i < piece.length; i++) {
                    var c = activePieceCol + piece[i][0];
                    var r = activePieceRow + piece[i][1];
                    if (r >= 0) settledBlocks.push([c, r]);
                }
                clearFullRows();
                var tooFull = false;
                for (var s = 0; s < settledBlocks.length; s++) {
                    if (settledBlocks[s][1] <= 0) { tooFull = true; break; }
                }
                if (tooFull) settledBlocks = [];
                spawnPiece();
            }
            clearAndRefresh();
        }

        Timer {
            id: gameTimer
            interval: 800
            running: root.playing
            repeat: true
            onTriggered: tetrisView.tick()
        }
    }
}
