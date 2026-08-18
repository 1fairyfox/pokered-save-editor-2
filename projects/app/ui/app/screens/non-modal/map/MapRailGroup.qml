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
  MapRailGroup.qml -- a GROUP of rail buttons, collapsed to ONE.

  Project leadership, 2026-07-14: *"collapse the left toolbar button groups into a single button each — I count
  three-or-more groups, so reduce it down to three buttons."*

  So the left rail is three groups: the tools (select / pan / zoom), the makers (place a door / place a
  person), and the panels (layers / characters / details). Each is now ONE button that shows the
  group's ACTIVE member (or the last one you picked from it), wears a small corner ◢ to say "there is
  more in here", and flies the members out to the right when you click it. Pick one and it collapses.

  The face is reactive -- exactly the preference from the top-bar pass: it shows what is ACTIVE, not a
  generic group glyph. So the tools button shows the select / pan / zoom icon depending on which tool
  is in hand, and the panels button shows the icon of whatever panel is open.

  ## ⭐ CLICKING THE FACE PICKS THE TOOL. It does NOT open the flyout. (2026-08-18)

  Project leadership: *"clicking the buttons with a dropout to pick others -- the 2 on the left bar at
  the top -- it needs to click whats there by default not open the menu to select. There needs to be a
  seperate thing that allows the user to open the dropout menu to select others. Research how photoshop
  does it."*

  **How Photoshop does it**, and what we take: the tool button is the tool. A single click selects the
  tool shown on the face -- one click, no menu, no second decision. A small triangle in the corner says
  "there are relatives in here", and the flyout is a *separate, deliberate* gesture:

    * **click the ◢ corner** -- our primary affordance, because it is visible and discoverable;
    * **press and hold** anywhere on the face (Photoshop's own gesture, ~400 ms);
    * **right-click** the face (Photoshop supports this too).

  So the common case -- "I want the tool I can see" -- costs one click, and the rare case -- "I want its
  sibling" -- costs a deliberate one. Before this, EVERY tool selection cost two clicks and a menu,
  including re-picking the tool already on the face.
*/
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: grp

  /// The members, in flyout order: `[{ id, icon | glyph, tip, shortcut? }]`. `icon` is a qrc path to a
  /// monochrome SVG and wins over `glyph`. @see MapRailButton
  property var members: []

  /// The id of the member that is currently ACTIVE — the tool in hand, the panel that is open — or ""
  /// if nothing in this group is active. The face shows it, lit; otherwise the face shows @ref
  /// lastPicked. The caller binds this (e.g. `activeId: mapScreen.tool` for the tools group).
  property string activeId: ""

  /// The tooltip on the collapsed face button.
  property string tip: ""

  /// Extra content rendered in the flyout AFTER the member buttons — the tools group hands it the
  /// zoom ▾ (ZoomMenu), so the zoom slider + "Go to…" still have exactly one home, inside the group.
  default property alias flyoutExtra: extra.data

  /// Emitted when a member is chosen from the flyout. The caller does the thing (set the tool, open
  /// the panel).
  signal chosen(string id)

  /// Whether the flyout is open. Exposed (with an objectName) so the screenshot harness can open it.
  property bool expanded: false

  /// What the face shows when nothing is active: the last member picked, defaulting to the first.
  property string lastPicked: members.length > 0 ? members[0].id : ""

  readonly property string shownId: grp.activeId !== "" ? grp.activeId : grp.lastPicked

  implicitWidth: 32
  implicitHeight: 32

  function memberOf(id) {
    for (let i = 0; i < grp.members.length; i++)
      if (grp.members[i].id === id)
        return grp.members[i];
    return grp.members.length > 0 ? grp.members[0] : undefined;
  }

  function glyphOf(id) {
    const m = grp.memberOf(id);
    return (m !== undefined && m.glyph !== undefined) ? m.glyph : "";
  }

  function iconOf(id) {
    const m = grp.memberOf(id);
    return (m !== undefined && m.icon !== undefined) ? m.icon : "";
  }

  // ── The collapsed face ─────────────────────────────────────────────────────────────────────
  //
  // ⚠️ A CLICK HERE PICKS THE TOOL, it does not open the flyout. @see the Photoshop note in the
  // header. The flyout has its own affordances below.
  MapRailButton {
    id: face
    anchors.fill: parent

    icon: grp.iconOf(grp.shownId)
    glyph: grp.glyphOf(grp.shownId)
    active: grp.activeId !== "" || grp.expanded
    tip: grp.tip

    onClicked: {
      grp.expanded = false;
      grp.lastPicked = grp.shownId;
      grp.chosen(grp.shownId);
    }
  }

  // PRESS-AND-HOLD and RIGHT-CLICK open the flyout — Photoshop's own two gestures, riding above the
  // face's MouseArea. `acceptedButtons` includes Left so the hold can be timed; the left press is NOT
  // accepted (`propagateComposedEvents` + no `onClicked`), so the face still gets its ordinary click.
  MouseArea {
    id: holdArea
    anchors.fill: parent
    acceptedButtons: Qt.RightButton
    onClicked: grp.expanded = !grp.expanded
  }

  Timer {
    id: holdTimer
    interval: 400
    onTriggered: grp.expanded = true
  }

  // The hold is timed off the FACE's own press state, so it costs no extra grab and cannot swallow
  // the click: hold past 400 ms and the flyout opens; release before that and the click lands.
  Connections {
    target: face
    function onPressedChanged() {
      if (face.pressed)
        holdTimer.restart();
      else
        holdTimer.stop();
    }
  }

  // ── The flyout's own affordance: the ◢ corner, and it is CLICKABLE ─────────────────────────
  //
  // The mark was always here saying "there is more in this group"; now it is the thing you press to
  // see it. Kept small and quiet (it is the rare path), but given a real 12px hit area so it is not a
  // pixel hunt, and a pointing cursor so it reads as a control rather than a decoration.
  Item {
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    width: 12
    height: 12

    Text {
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.rightMargin: 1
      anchors.bottomMargin: 0

      text: "◢"
      font.pixelSize: cornerHover.hovered ? 9 : 7
      color: face.active ? brg.settings.textColorLight : brg.settings.textColorMid
      opacity: cornerHover.hovered ? 1.0 : 0.8
      Behavior on font.pixelSize { NumberAnimation { duration: 60 } }
    }

    HoverHandler { id: cornerHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: grp.expanded = !grp.expanded }

    MapToolTip {
      shown: cornerHover.hovered
      text: qsTr("More in this group — or press and hold the button")
    }
  }

  // ── The flyout ─────────────────────────────────────────────────────────────────────────────
  //
  // Pops to the RIGHT, over the canvas, so the rail stays narrow. Click a member to pick it; click
  // away (or Esc) to dismiss without choosing.
  Popup {
    id: fly

    visible: grp.expanded
    onClosed: grp.expanded = false

    x: face.width + 5
    y: -3
    padding: 4

    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    background: Rectangle {
      color: "#ffffff"
      radius: 8
      border.width: 1
      border.color: brg.settings.dividerColor
    }

    contentItem: RowLayout {
      spacing: 3

      Repeater {
        model: grp.members

        MapRailButton {
          required property var modelData

          objectName: "toolBtn_" + modelData.id   // the DEBUG harness still finds tools by name
          size: 30
          icon: modelData.icon !== undefined ? modelData.icon : ""
          glyph: modelData.glyph !== undefined ? modelData.glyph : ""
          tip: modelData.tip
          shortcut: modelData.shortcut !== undefined ? modelData.shortcut : ""
          active: grp.activeId === modelData.id

          onClicked: {
            grp.lastPicked = modelData.id;
            grp.chosen(modelData.id);
            grp.expanded = false;
          }
        }
      }

      // The zoom ▾, when the caller supplies one. Sized to its child; invisible (and space-free) when
      // empty, so the makers/panels flyouts don't grow a phantom gap.
      Item {
        id: extra
        Layout.preferredWidth: childrenRect.width
        Layout.preferredHeight: 30
        Layout.alignment: Qt.AlignVCenter
        visible: childrenRect.width > 0
      }
    }
  }
}
