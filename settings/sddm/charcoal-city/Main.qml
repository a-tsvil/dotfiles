import QtQuick
import "../sddm-astronaut-theme" as Astronaut

Astronaut.Main {
    id: login

    Component.onCompleted: city.parent = login.contentItem.children[0]

    LeafDrift {
        id: city
        anchors.fill: parent
        z: 0.5
    }
}
