/*
  * Copyright 2026 Fairy Fox
  *
  * Licensed under the Apache License, Version 2.0 (the "License");
  * you may not use this file except in compliance with the License.
  * You may obtain a copy of the License at
  *
  *   http://www.apache.org/licenses/LICENSE-2.0
  *
  * Unless required by applicable law or agreed to in writing, software
  * distributed under the License is distributed on an "AS IS" BASIS,
  * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  * See the License for the specific language governing permissions and
  * limitations under the License.
*/

/*
  ColourPicker.qml -- the OUTPUT palette, as its OWN chip in the top bar (right side).

  Project leadership, 2026-07-19: *"move the color preview out of contrast … the color picker goes in the top
  bar at the right."* It used to be folded into the contrast dropdown; it is its own chip again now,
  because it is a DIFFERENT thing: **contrast is a save byte** (which of the four shades each pixel
  becomes) and **colour is a VIEW setting that changes not one byte of the save** (what those four
  shades are painted). The chip's face is the four colours it is currently painting with.

  Grey · Game Boy (the green screen) · Super Game Boy (each map in its own real colours) · Custom.
*/
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Item {
  id: root
  objectName: "colourPicker"

  implicitWidth: trigger.implicitWidth
  implicitHeight: 26

  /// Drive the drop-down open/shut by name (the DEBUG harness / screenshot review). @see MapPicker.
  property bool openState: false
  onOpenStateChanged: openState ? pop.open() : pop.close()

  /// The active preset's four colours, for the chip's face.
  readonly property var activeSwatch: {
    const ps = brg.map.colourPresets();
    for (let i = 0; i < ps.length; i++)
      if (ps[i].mode === brg.map.colourMode)
        return ps[i].swatch;
    return ["#ffffff", "#aaaaaa", "#555555", "#000000"];
  }

  MapBarButton {
    id: trigger
    anchors.fill: parent

    open: root.openState
    onToggle: root.openState = !root.openState

    tip: qsTr("Colour — how the four shades are painted (a view setting; no save change)")

    // The live swatch: the four colours this palette is currently drawn in.
    Row {
      anchors.verticalCenter: parent.verticalCenter
      spacing: 0

      Repeater {
        model: 4
        Rectangle {
          required property int index
          width: 5
          height: 13
          color: (root.activeSwatch && root.activeSwatch.length === 4)
                   ? root.activeSwatch[index] : "#f2f2f2"
          topLeftRadius: index === 0 ? 2 : 0
          bottomLeftRadius: index === 0 ? 2 : 0
          topRightRadius: index === 3 ? 2 : 0
          bottomRightRadius: index === 3 ? 2 : 0
        }
      }
    }
  }

  // ── The drop-down ───────────────────────────────────────────────────────────────────────────
  Popup {
    id: pop

    y: root.height + 4
    x: -180   // the chip sits on the right of the bar; open the panel back toward the left
    width: 240
    padding: 10
    margins: 8   // keep inside the window at the semi-fluid minimum (never clip the bottom)

    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    background: Rectangle {
      color: "#ffffff"
      radius: 6
      border.width: 1
      border.color: brg.settings.dividerColor
    }

    ColumnLayout {
      anchors.fill: parent
      spacing: 8

      RowLayout {
        Layout.fillWidth: true
        Text {
          Layout.fillWidth: true
          text: qsTr("Colour")
          font.pixelSize: 11
          font.bold: true
          color: brg.settings.textColorMid
        }
        Text {
          text: qsTr("view only — no save change")
          font.pixelSize: 9
          font.italic: true
          color: brg.settings.textColorMid
          opacity: 0.75
        }
      }

      // ── The presets ──────────────────────────────────────────────────────────────────────────
      Repeater {
        model: brg.map.colourPresets()

        delegate: Rectangle {
          id: colRow
          required property var modelData

          Layout.fillWidth: true
          implicitHeight: 28
          radius: 5

          readonly property bool active: brg.map.colourMode === modelData.mode

          color: colRow.active        ? Qt.rgba(0.34, 0.71, 0.91, 0.16)
               : colRowHover.hovered  ? Qt.rgba(0, 0, 0, 0.06)
               : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: 8

            Row {
              spacing: 0
              Repeater {
                model: colRow.modelData.swatch
                Rectangle {
                  required property var modelData
                  width: 8
                  height: 16
                  color: modelData
                }
              }
            }

            Text {
              Layout.fillWidth: true
              text: colRow.modelData.name
              font.pixelSize: 12
              font.bold: colRow.active
              color: brg.settings.textColorDark
            }
          }

          HoverHandler { id: colRowHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: brg.map.colourMode = colRow.modelData.mode }
        }
      }

      // ── The custom swatches — only when Custom is chosen ─────────────────────────────────────
      RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        visible: brg.map.colourMode === 3
        spacing: 4

        Text {
          text: qsTr("Shades")
          font.pixelSize: 10
          color: brg.settings.textColorMid
        }

        Item { Layout.fillWidth: true }

        Repeater {
          model: 4
          delegate: Rectangle {
            required property int index
            width: 26
            height: 22
            radius: 4
            color: brg.map.customColours()[index]
            border.width: 1
            border.color: swHover.hovered ? "#56b4e9" : brg.settings.dividerColor

            HoverHandler { id: swHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
              onTapped: {
                colourDialog.shade = index;
                colourDialog.selectedColor = brg.map.customColours()[index];
                colourDialog.open();
              }
            }
          }
        }
      }
    }
  }

  ColorDialog {
    id: colourDialog
    property int shade: 0
    onAccepted: brg.map.setCustomColour(colourDialog.shade, colourDialog.selectedColor)
  }
}
