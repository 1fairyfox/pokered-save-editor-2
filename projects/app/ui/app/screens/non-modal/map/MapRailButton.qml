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
  MapRailButton.qml -- one square button on a rail (the tool rail, the dock rail, a bar).

  The app's flat language, in a square: nothing at rest, a soft wash on hover, the accent fill when
  it is the active one. Deliberately NOT a Material Button -- Qt 6.5+ gives those a large implicit
  height and width that fights any small control (ui-patterns.md -> "Material controls fight small
  heights"), and a rail of them would be a row of 40px pills.

  ⚠️ **`icon` FIRST, `glyph` as the fallback** (project leadership, 2026-08-18: *"the icon for placing
  people is very non-intuitive please make it much better remember you can use fontawesome free"* …
  *"characters wild pokemon all of that needs way better icons"*).

  This file used to say "a glyph, not an icon file", and for the rail that turned out to be wrong: a
  typographic dingbat is only legible when it happens to *be* the thing (⇄ reads as a swap), and most
  of this screen's subjects have no dingbat at all. `☻` for "place a person" was the worst of them --
  it reads as a mood, not as an action. Font Awesome is the app's existing house set (it is already in
  `credits.json`, and 61 of its icons were already bundled), so the rail now draws a real icon and
  keeps `glyph` only for marks that genuinely are typographic. The flat language is unchanged: the
  icon is monochrome and recoloured by state, exactly as the glyph was.
*/
import QtQuick
import QtQuick.Controls
import QtQuick.Effects

Rectangle {
  id: btn

  /// A qrc path to a monochrome SVG. When set it wins over `glyph`.
  property string icon: ""

  property string glyph: ""
  property string tip: ""
  property bool active: false
  property bool enabledBtn: true
  /// A PRIMARY button is marked as special at rest -- the Map Storage (persistent storage /
  /// "World") icon. ⚠️ RESTYLED 2026-07-18 (leadership: *"needs to be a different background
  /// color than the one used to determine which menu or panel is selected/open"*): the old
  /// treatment filled it with the ACCENT at rest, which is exactly the open-panel look -- it
  /// permanently read as "this panel is open". Now: a light accent WASH + accent outline at
  /// rest, and only a genuinely open panel gets the solid accent fill.
  property bool primary: false
  property int size: 32
  /// A one-key shortcut, shown in the tooltip. The keys themselves are bound by the screen.
  property string shortcut: ""

  signal clicked()

  /// True while the pointer is held down on this button. MapRailGroup times its press-and-hold off
  /// this rather than adding a second grabbing MouseArea (which would swallow the click).
  readonly property bool pressed: ma.containsPress

  implicitWidth: size
  implicitHeight: size
  radius: 4

  color: !enabledBtn ? "transparent"
       : active      ? brg.settings.accentColor
       : ma.containsPress ? "#22000000"
       : primary     ? Qt.alpha(brg.settings.accentColor, ma.containsMouse ? 0.28 : 0.16)
       : ma.containsMouse ? "#14000000"
       : "transparent"

  // The primary mark: a quiet accent OUTLINE, never the open-panel fill.
  border.width: primary && !active ? 1 : 0
  border.color: Qt.alpha(brg.settings.accentColor, 0.55)

  opacity: enabledBtn ? 1.0 : 0.35

  Behavior on color { ColorAnimation { duration: 90 } }

  /// The one ink for whatever this button draws — icon and glyph agree by construction.
  ///
  /// ⚠️ AN ICON IS NOT A GLYPH'S WEIGHT. First cut drew Font Awesome **solid** at `textColorDark`,
  /// the same ink the old dingbats used, and project leadership's reaction was immediate: *"the icons
  /// are ugly black and extremely huge."* Both halves are the same root cause — a text glyph is mostly
  /// whitespace (a 16 px "☻" has ~11 px of cap height and thin strokes), while an FA solid icon is a
  /// filled shape that runs edge to edge of its box. Matching the *number* made the icon ~40% bigger
  /// and several times heavier on the page.
  ///
  /// So at rest the icon takes the MID ink, not the dark one — it is chrome, not content — and it
  /// only goes full-strength when the button is active or under the cursor.
  readonly property color markColor: btn.active ? brg.settings.textColorLight
                                                : ma.containsMouse ? brg.settings.textColorDark
                                                                   : brg.settings.textColorMid

  Text {
    anchors.centerIn: parent
    visible: btn.icon === ""
    text: btn.glyph
    font.pixelSize: Math.round(btn.size * 0.5)
    color: btn.markColor
  }

  // The SVG is black on transparent, so it is RECOLOURED rather than tinted — a MultiEffect
  // colourization, the same treatment the rest of the app's Font Awesome buttons use.
  //
  // ⚠️ 34% OF THE BUTTON, NOT 46%. An FA icon fills its box; a glyph does not. Sizing the icon to
  // the old glyph's *font size* made it visibly huge (leadership: *"extremely huge"*). 34% of a 32 px
  // button is ~11 px — which is the old dingbat's actual drawn height, not its font size. @see
  // markColor for the other half of the same mistake.
  Image {
    id: iconImg
    anchors.centerIn: parent
    visible: false                      // the effect draws it; @see reference/qt-patterns.md
    source: btn.icon
    sourceSize.width: Math.round(btn.size * 0.34)
    sourceSize.height: Math.round(btn.size * 0.34)
    fillMode: Image.PreserveAspectFit
    mipmap: true
  }

  MultiEffect {
    anchors.fill: iconImg
    visible: btn.icon !== ""
    source: iconImg
    colorization: 1.0
    colorizationColor: btn.markColor
  }

  MouseArea {
    id: ma
    anchors.fill: parent
    hoverEnabled: true
    enabled: btn.enabledBtn
    cursorShape: btn.enabledBtn ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: btn.clicked()
  }

  // Hover shows it. Not "hover, if you first found the ? toggle in the header" -- see MapToolTip.
  MapToolTip {
    shown: ma.containsMouse && btn.tip !== ""
    text: btn.shortcut === "" ? btn.tip : btn.tip + "  (" + btn.shortcut + ")"
  }
}
