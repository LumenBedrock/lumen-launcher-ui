import QtQuick

// The Lumen star drawn on a 12×12 pixel grid
Item {
    id: star
    property int pixelSize: 8
    width: 12 * pixelSize
    height: 12 * pixelSize

    Repeater {
        // [x, y, w, h, colour] in grid cells
        model: [
            [5, 0, 2, 12, 0], [0, 5, 12, 2, 0],
            [4, 2, 4, 8, 0], [2, 4, 8, 4, 0],
            [4, 4, 4, 4, 1], [5, 5, 2, 2, 2],
            [7, 2, 1, 1, 3], [9, 7, 1, 1, 3], [3, 8, 1, 1, 3]
        ]
        Rectangle {
            required property var modelData
            x: modelData[0] * star.pixelSize
            y: modelData[1] * star.pixelSize
            width: modelData[2] * star.pixelSize
            height: modelData[3] * star.pixelSize
            // 0 glow colour, 1 lighter core, 2 white centre, 3 darker sparkle
            color: [window.lumenGlow, Qt.lighter(window.lumenGlow, 1.25), "#ffffff", Qt.darker(window.lumenGlow, 1.25)][modelData[4]]
            antialiasing: false
        }
    }
}
