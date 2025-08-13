import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    Slide {
        Image {
            source: "image.png"
            anchors.centerIn: parent
            fillMode: Image.PreserveAspectFit
        }
    }
}
