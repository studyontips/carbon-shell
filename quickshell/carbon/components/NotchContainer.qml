import QtQuick
import QtQuick.Shapes
import "../Singletons"

/**
 * Top-Attached Notch Container matching SaneAspect / Tide Island exact geometry:
 * - Native Rectangle body with clipped top corners and smooth convex bottom corners
 * - Native PathArc ear fillets curving outward seamlessly into the screen edge
 * - No fuzzy SVG approximations, no stroke outlines
 */
Item {
    id: root

    property bool leftFillet: true
    property bool rightFillet: true
    property real filletRadius: 10
    property real bottomRadius: 14
    property real contentSpacing: 7
    property real horizontalPadding: 12
    property real earWidth: 0

    default property alias content: contentRow.data
    readonly property real contentImplicitWidth: contentRow.implicitWidth

    implicitHeight: 32
    implicitWidth: Math.max(70, contentRow.implicitWidth 
                   + (leftFillet ? filletRadius : 0) 
                   + (rightFillet ? filletRadius : 0) 
                   + (horizontalPadding * 2))
    width: implicitWidth

    Behavior on width {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }
    height: implicitHeight
    Behavior on height {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    property bool attachedBottom: false
    property bool hasAttachedPopup: false
    property real notchOpacity: 0.96

    // SaneAspect deep dark OLED notch surface
    readonly property color notchBgColor: Theme.isDark 
        ? Qt.rgba(0.04, 0.04, 0.06, root.notchOpacity) 
        : Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, root.notchOpacity)

    // 1. Central Body: Clipped to hide top rounded corners, showing bottom convex corners
    Item {
        id: bodyClip
        clip: true
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: (root.leftFillet && root.filletRadius > 0) ? root.filletRadius : 0
        anchors.rightMargin: (root.rightFillet && root.filletRadius > 0) ? root.filletRadius : 0

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: (!root.leftFillet && root.rightFillet) ? -root.bottomRadius : 0
            anchors.right: parent.right
            anchors.rightMargin: (!root.rightFillet && root.leftFillet) ? -root.bottomRadius : 0
            anchors.top: root.attachedBottom ? undefined : parent.top
            anchors.topMargin: root.attachedBottom ? 0 : -root.bottomRadius
            anchors.bottom: root.attachedBottom ? parent.bottom : undefined
            anchors.bottomMargin: root.attachedBottom ? -root.bottomRadius : 0
            height: parent.height + root.bottomRadius
            radius: root.bottomRadius
            color: root.notchBgColor
        }
    }

    // 2. Left Ear Fillet (SaneAspect exact PathArc geometry)
    Shape {
        id: leftEar
        visible: root.leftFillet && root.filletRadius > 0
        x: 0
        y: root.attachedBottom ? (root.height - root.filletRadius) : 0
        width: root.filletRadius
        height: root.filletRadius
        preferredRendererType: Shape.GeometryRenderer
        antialiasing: true
        asynchronous: false

        ShapePath {
            fillColor: root.notchBgColor
            strokeColor: "transparent"
            strokeWidth: 0
            startX: 0
            startY: root.attachedBottom ? leftEar.height : 0
            PathLine { x: leftEar.width; y: root.attachedBottom ? leftEar.height : 0 }
            PathLine { x: leftEar.width; y: root.attachedBottom ? 0 : leftEar.height }
            PathArc {
                x: 0
                y: root.attachedBottom ? leftEar.height : 0
                radiusX: leftEar.width
                radiusY: leftEar.height
                direction: root.attachedBottom ? PathArc.Clockwise : PathArc.Counterclockwise
            }
        }
    }

    // 3. Right Ear Fillet (SaneAspect exact PathArc geometry)
    Shape {
        id: rightEar
        visible: root.rightFillet && root.filletRadius > 0
        x: root.width - root.filletRadius
        y: root.attachedBottom ? (root.height - root.filletRadius) : 0
        width: root.filletRadius
        height: root.filletRadius
        preferredRendererType: Shape.GeometryRenderer
        antialiasing: true
        asynchronous: false

        ShapePath {
            fillColor: root.notchBgColor
            strokeColor: "transparent"
            strokeWidth: 0
            startX: 0
            startY: root.attachedBottom ? 0 : rightEar.height
            PathLine { x: 0; y: root.attachedBottom ? rightEar.height : 0 }
            PathLine { x: rightEar.width; y: root.attachedBottom ? rightEar.height : 0 }
            PathArc {
                x: 0
                y: root.attachedBottom ? 0 : rightEar.height
                radiusX: rightEar.width
                radiusY: rightEar.height
                direction: root.attachedBottom ? PathArc.Clockwise : PathArc.Counterclockwise
            }
        }
    }

    property bool isPlaying: false
    property string trackTitle: ""
    property alias mouseArea: notchMouseArea

    MouseArea {
        id: notchMouseArea
        anchors.fill: parent
        hoverEnabled: false
        cursorShape: Qt.ArrowCursor
        z: 0
    }

    Row {
        id: contentRow
        z: 1
        anchors.top: root.attachedBottom ? undefined : parent.top
        anchors.topMargin: root.attachedBottom ? undefined : Math.max(0, (Math.min(root.height, 32) - contentRow.height) / 2)
        anchors.bottom: root.attachedBottom ? parent.bottom : undefined
        anchors.bottomMargin: root.attachedBottom ? Math.max(0, (Math.min(root.height, 32) - contentRow.height) / 2) : undefined
        anchors.left: (!root.rightFillet && root.leftFillet) ? undefined : ((root.leftFillet && root.rightFillet) ? undefined : parent.left)
        anchors.leftMargin: (!root.rightFillet && root.leftFillet) ? undefined : ((root.leftFillet && root.rightFillet) ? undefined : ((root.leftFillet ? root.filletRadius : 0) + root.horizontalPadding))
        anchors.right: (!root.rightFillet && root.leftFillet) ? parent.right : undefined
        anchors.rightMargin: (!root.rightFillet && root.leftFillet) ? root.horizontalPadding : undefined
        anchors.horizontalCenter: (root.leftFillet && root.rightFillet) ? parent.horizontalCenter : undefined
        spacing: root.contentSpacing
    }
}
