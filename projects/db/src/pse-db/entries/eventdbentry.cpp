/*
  * Copyright 2020 Fairy Fox
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

/**
 * @file eventdbentry.cpp
 * @brief Implementation of EventDBEntry. See eventdbentry.h.
 */

#include <QVector>
#include <QJsonArray>
#include <QQmlEngine>
#include <pse-common/utility.h>

#ifdef QT_DEBUG
#include <QtDebug>
#endif

#include "../eventsdb.h"
#include "../util/gamedata.h"
#include "../mapsdb.h"
#include "mapdbentry.h"

#include "eventdbentry.h"

EventDBEntry::EventDBEntry() {
  qmlRegister();
}
EventDBEntry::EventDBEntry(QJsonValue& data)
{
  qmlRegister();
  // Set simple properties
  name = data["name"].toString();
  ind = data["ind"].toDouble();
  byte = data["byte"].toDouble();
  bit = data["bit"].toDouble();

  for(auto eventMap : data["maps"].toArray())
    maps.append(eventMap.toString());

  // The research payload (events.json is generated from pret by
  // scripts/import_events_db.py). Every field is OPTIONAL -- a missing one just
  // leaves the default -- so the DB still loads if the file is ever trimmed.
  desc = data["description"].toString();
  group = data["group"].toString();
  region = data["region"].toString();
  caution = data["caution"].toString();
  placeholder = data["placeholder"].toBool(false);
  shared = data["shared"].toBool(false);
  // -1 when the field is absent (an older events.json), which must NOT be read as "0 reads".
  // @see the members' comment: unknown is treated as in-use, never as useless.
  writes = data["writes"].toInt(-1);
  reads = data["reads"].toInt(-1);
  clears = data["clears"].toInt(-1);
  tableRefs = data["tableRefs"].toInt(-1);
  for(auto c : data["classification"].toArray())
    classification.append(c.toString());
}

void EventDBEntry::deepLink()
{
  for(const auto& map : maps)
  {
    auto tmp = MapsDB::inst()->getIndAt(map);
    toMaps.append(tmp);

#ifdef QT_DEBUG
    if(tmp == nullptr)
      qCritical() << "Events: " << name << ", could not be deep linked to map " << map ;
#endif

    if(tmp != nullptr)
      tmp->toEvents.append(this);
  }
}

void EventDBEntry::qmlRegister() const
{
  static bool once = false;
  if(once)
    return;

  qmlRegisterUncreatableType<EventDBEntry>("PSE.DB.EventDBEntry", 1, 0, "EventDBEntry", "Can't instantiate in QML");
  once = true;
}

const QVector<MapDBEntry*> EventDBEntry::getToMaps() const
{
  return toMaps;
}

int EventDBEntry::getToMapsSize() const
{
  return toMaps.size();
}

const MapDBEntry* EventDBEntry::getToMapAt(int ind) const
{
  if(ind >= toMaps.size())
    return nullptr;

  return toMaps.at(ind);
}

void EventDBEntry::qmlProtect(const QQmlEngine* const engine) const
{
  Utility::qmlProtectUtil(this, engine);
}

const QVector<QString> EventDBEntry::getMaps() const
{
  return maps;
}

int EventDBEntry::getMapsSize() const
{
  return maps.size();
}

const QString EventDBEntry::getMapAt(int ind) const
{
  if(ind >= maps.size())
    return nullptr;

  return maps.at(ind);
}

int EventDBEntry::getBit() const
{
    return bit;
}

int EventDBEntry::getByte() const
{
    return byte;
}

int EventDBEntry::getInd() const
{
    return ind;
}

const QString EventDBEntry::getName() const
{
    return name;
}

const QString EventDBEntry::getDesc() const
{
    return desc;
}

const QString EventDBEntry::getGroup() const
{
    return group;
}

const QString EventDBEntry::getRegion() const
{
    return region;
}

const QString EventDBEntry::getCaution() const
{
    return caution;
}

bool EventDBEntry::getPlaceholder() const
{
    return placeholder;
}

bool EventDBEntry::getShared() const
{
    return shared;
}

int EventDBEntry::getWrites() const
{
    return writes;
}

int EventDBEntry::getReads() const
{
    return reads;
}

int EventDBEntry::getClears() const
{
    return clears;
}

int EventDBEntry::getTableRefs() const
{
    return tableRefs;
}

bool EventDBEntry::isEverRead() const
{
    // Unknown (< 0) means the data file predates these counts. Answer TRUE: a missing fact must
    // never be the reason a real flag disappears from the panel.
    if(reads < 0 || tableRefs < 0)
        return true;

    // A script that checks it, OR a data table the engine reads it through -- a `trainer` entry
    // in a map's header list is every bit as real a read as an `if` in a script.
    return reads > 0 || tableRefs > 0;
}

const QVector<QString> EventDBEntry::getClassification() const
{
    return classification;
}

