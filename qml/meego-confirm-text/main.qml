import QtQuick 1.1
import com.nokia.meego 1.0

PageStackWindow {
    id: appWindow

    Item {
        id: content
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.top: parent.top
        anchors.topMargin: 45
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 15

        Text {
            id: textTitle
            width: parent.width
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 36

            text: title
        }

        TextArea {
            // We can't specify a minimum height for a TextArea. Therefore, use
            // a fixed, empty TextArea and draw the actual Text on top of it.
            id: textArea
            width: parent.width
            anchors.top: textTitle.bottom
            anchors.topMargin: 10
            anchors.bottom: rowConfirm.top
            anchors.bottomMargin: 10
            readOnly: true

            Flickable {
                id: flickArea
                width: parent.width
                anchors.top: parent.top
                anchors.topMargin: 20
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.left: parent.left
                anchors.leftMargin: 20

                contentWidth: flickArea.width; contentHeight: textMessage.height
                flickableDirection: Flickable.VerticalFlick
                clip: true

                Text {
                    id: textMessage
                    width: parent.width
                    font.pixelSize: 20
                    wrapMode: Text.Wrap

                    text: message
                }
            }
        }


        Item {
            id: rowConfirm
            width: parent.width
            height: 50
            anchors.bottom: content.bottom

            Switch {
                id: switchConfirm
            }

            Text {
                id: textConfirm
                width: 200
                height: switchConfirm.height
                anchors.left: switchConfirm.right
                anchors.leftMargin: 10
                verticalAlignment: Text.AlignVCenter
                text: switchConfirm.checked ? "I Agree" : "I Disagree"
                font.pixelSize: 24
            }

            Button {
                id: buttonConfirm
                anchors.right: rowConfirm.right
                width: 150
                height: switchConfirm.height
                text: "Confirm"
                onClicked: switchConfirm.checked ? returnClass.confirmAgreement(0) : returnClass.confirmAgreement(1)
            }
        }
    }
}

