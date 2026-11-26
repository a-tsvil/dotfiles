import QtQuick

Item {
    id: scene
    clip: true

    property real frame: 0
    readonly property real pixel: Math.max(1, Math.round(width / 960))
    readonly property real backgroundScale: Math.max(width / 1672, height / 941)

    Image {
        objectName: "wallpaper"
        anchors.fill: parent
        source: "background.png"
        fillMode: Image.PreserveAspectCrop
        smooth: false
        mipmap: false
        z: -1
    }
    readonly property var leafHues: ["#a95428", "#b08a35", "#813e2c", "#73834b", "#9c9354", "#65442e", "#4c6244", "#854c44"]
    readonly property var leafForms: [
        [ ["....##....", "..#.###...", ".#######..", "..#######.", ".########.", "..######..", "...####...", "....##....", "....#....."],
          [".....#....", "....##....", "...####...", "....###...", "...####...", "....##....", "....##....", "....#.....", "....#....."],
          ["..........", "..........", "..##.##...", ".########.", "########..", "..#####...", "....##....", "....#.....", ".........."] ],
        [ ["....#.....", ".#..##..#.", ".########.", "..######..", "##########", "..######..", "...####...", "....##....", "....#....."],
          ["....#.....", "....##....", "...###....", "....###...", "...####...", "....##....", "...##.....", "....#.....", "....#....."],
          ["..........", "....#.....", "..#####...", "#########.", ".#######..", "...####...", "....#.....", "..........", ".........."] ],
        [ [".......#..", "......##..", ".....###..", "....###...", "...###....", "..###.....", ".###......", "###.......", "#........."],
          ["......#...", ".....##...", ".....#....", "....##....", "....#.....", "...##.....", "...#......", "..##......", "..#......."],
          ["..........", "..........", ".......##.", "....#####.", "..######..", "#####.....", "##........", "..........", ".........."] ],
        [ ["...####...", "..######..", ".########.", ".########.", "..#######.", "...#####..", "....###...", ".....#....", ".....#...."],
          ["....##....", "...###....", "...####...", "...####...", "....###...", "....##....", "....##....", ".....#....", ".....#...."],
          ["..........", "...####...", ".########.", "#########.", "..######..", "....###...", ".....#....", "..........", ".........."] ],
    ]

    Timer {
        interval: 125
        running: scene.visible
        repeat: true
        onTriggered: scene.frame += 1
    }

    Repeater {
        model: 12

        Item {
            id: leaf
            required property int index
            objectName: "leaf" + index
            property int lifetime: 384 + Math.floor(Math.random() * 384)
            property int spawnOffset: Math.floor(Math.random() * lifetime)
            readonly property int phase: (scene.frame + spawnOffset) % lifetime
            readonly property int cycle: Math.floor((scene.frame + spawnOffset) / lifetime)
            readonly property real progress: phase / lifetime
            readonly property int verticalTrend: index % 3 - 1
            property real spawnY: 0.87
            property real swirlPhase: 0
            property real swirlTurns: 3
            readonly property real angle: progress * swirlTurns * Math.PI * 2 + swirlPhase
            readonly property real windProgress: progress + Math.sin(progress * Math.PI)
                * (0.012 * Math.sin(angle) + 0.004 * Math.sin(angle * 2.3))
            readonly property real margin: width + 12 * scene.pixel

            function respawn() {
                spawnY = 0.84 + Math.random() * 0.06
                swirlPhase = Math.random() * Math.PI * 2
                swirlTurns = (2 + Math.random() * 2) * (index % 2 ? -1 : 1)
            }

            Component.onCompleted: respawn()
            onCycleChanged: respawn()
            readonly property int animationFrame: Math.floor(phase / (3 + index % 3)) % 3
            readonly property color leafColor: scene.leafHues[index % scene.leafHues.length]
            readonly property var rows: scene.leafForms[index % scene.leafForms.length][animationFrame]

            width: rows[0].length * scene.pixel
            height: rows.length * scene.pixel
            x: Math.round(((scene.width + 2 * margin) * (1 - windProgress)
                - margin) / scene.pixel) * scene.pixel
            y: Math.round(scene.height * (spawnY + verticalTrend * 0.09 * (progress - 0.5)
                + 0.009 * Math.sin(angle * 2.1)
                + 0.004 * Math.sin(angle * 4.7 + swirlPhase)) / scene.pixel) * scene.pixel
            z: 2
            rotation: index % 2 * 180

            Repeater {
                model: leaf.rows.length

                Item {
                    readonly property int row: index
                    y: row * scene.pixel

                    Repeater {
                        model: leaf.rows[0].length

                        Rectangle {
                            x: index * scene.pixel
                            width: scene.pixel
                            height: scene.pixel
                            color: index === 5 ? Qt.lighter(leaf.leafColor, 1.2) : leaf.leafColor
                            visible: leaf.rows[parent.row][index] === "#"
                        }
                    }
                }
            }
        }
    }

    Repeater {
        model: [
            {x: 544, y: 22, skyX: 531, skyY: 10, stem: "#012f3c"},
            {x: 395, y: 154, skyX: 383, skyY: 143, stem: "#02323a"},
            {x: 1647, y: 237, skyX: 1635, skyY: 226, stem: "#002933"},
            {x: 58, y: 285, skyX: 65, skyY: 277, stem: "#000a0f"},
            {x: 41, y: 294, skyX: 27, skyY: 282, stem: "#002a32"}
        ]

        Item {
            required property int index
            required property var modelData
            objectName: "towerLight" + index
            width: 4 * scene.backgroundScale
            height: width
            x: (scene.width - 1672 * scene.backgroundScale) / 2 + modelData.x * scene.backgroundScale - width / 2
            y: (scene.height - 941 * scene.backgroundScale) / 2 + modelData.y * scene.backgroundScale - height / 2
            readonly property color color: "#ff6753"
            readonly property real brightness: Math.pow(Math.max(0, Math.sin(scene.frame * Math.PI / 24 + index * 2.1)), 2)

            Image {
                anchors.centerIn: parent
                width: 10 * scene.backgroundScale
                height: width
                source: "background.png"
                sourceClipRect: Qt.rect(parent.modelData.skyX, parent.modelData.skyY, 10, 10)
                smooth: false
                mipmap: false
            }

            Rectangle {
                x: parent.width / 2 - width / 2
                y: parent.height / 2
                width: scene.backgroundScale
                height: 5 * scene.backgroundScale
                color: parent.modelData.stem
            }

            Rectangle {
                anchors.fill: parent
                color: parent.color
                opacity: parent.brightness

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 3
                    height: width
                    color: parent.color
                    opacity: 0.22
                }
            }
        }
    }
}
