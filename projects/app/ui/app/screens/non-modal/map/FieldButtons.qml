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
  FieldButtons.qml -- the small right-aligned action cluster for a panel field (project leadership,
  2026-08-03: *"have the usual buttons … re-roll/randomize and revert, right aligned"*).

  A 🎲 that randomizes the field to a sensible VALID value, and (when `showRevert` is set) a ↩ that
  reverts it to the last-saved value. Font Awesome icons, the house set. Drop it at the end of a
  field's RowLayout; it emits `randomize()` / `revert()` for the caller to wire to the model.

  ⚠️ `showRevert` defaults FALSE: the revert half rides in on the save-snapshot phase (there is no
  "last saved value" source wired yet). Until then a field shows only the 🎲.
*/
import QtQuick
import QtQuick.Layouts

Row {
  id: fb

  signal randomize()
  signal revert()

  /// Show the ↩ revert button (off until the save-snapshot mechanism lands).
  property bool showRevert: false

  spacing: 4

  component ActBtn: Rectangle {
    id: btn
    property alias icon: img.source
    property string tip: ""
    signal clicked()

    width: 30
    height: 30
    radius: 4
    color: hov.hovered ? "#f0f0f0" : "transparent"
    border.width: 1
    border.color: Qt.rgba(0, 0, 0, 0.18)

    Image {
      id: img
      anchors.centerIn: parent
      width: 15; height: 15
      sourceSize: Qt.size(30, 30)
      fillMode: Image.PreserveAspectFit
      smooth: true
    }

    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: btn.clicked() }

    MapToolTip { shown: hov.hovered && btn.tip !== ""; text: btn.tip }
  }

  ActBtn {
    icon: "qrc:/assets/icons/fontawesome/dice.svg"
    tip: qsTr("Randomize — a sensible random value (never a glitch)")
    onClicked: fb.randomize()
  }

  ActBtn {
    visible: fb.showRevert
    icon: "qrc:/assets/icons/fontawesome/undo.svg"
    tip: qsTr("Revert to the last saved value")
    onClicked: fb.revert()
  }
}
