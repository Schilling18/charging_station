// Created 14.03.2024 by Christopher Schilling
//
// The file stores logicfunctions, which are used across the project.
//
// __version__ = "1.0.4"
//
// __author__ = "Christopher Schilling"
//
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:charging_station/models/api.dart';

const String _selectedSpeedKey = 'selected_speed';
const String _selectedPlugsKey = 'selected_plugs';
const String _selectedParkingSensorKey = 'selected_parking_sensor';

const plugTypeMap = {
  'Typ2': 'IEC_62196_T2',
  'CCS': 'IEC_62196_T2_COMBO',
  'CHAdeMO': 'CHADEMO',
  'Tesla': 'TESLA',
};

/// Berechnet die Entfernung zwischen der aktuellen Position und einer Ladestation
double calculateDistance(Position currentPosition, LatLng stationPosition) {
  double distanceInMeters = Geolocator.distanceBetween(
    currentPosition.latitude,
    currentPosition.longitude,
    stationPosition.latitude,
    stationPosition.longitude,
  );
  return distanceInMeters / 1000;
}

/// Formatiert die Entfernung zur Ladestation (m, wenn < 1 km, sonst km)
String formatDistance(double distance) {
  if (distance < 1) {
    return '${(distance * 1000).toStringAsFixed(0)} m';
  } else {
    return '${distance.toStringAsFixed(2)} km';
  }
}

/// Zeigt einen Dialog an, wenn die Standortberechtigung verweigert wurde
void showPermissionDeniedDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Standortberechtigung verweigert"),
        content: const Text(
            "Um nahegelegene Ladestationen korrekt anzuzeigen, ist ein Standortzugriff erforderlich. Dies kann in den Einstellungen geändert werden."),
        actions: <Widget>[
          TextButton(
            child: const Text("OK"),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

/// Bewegt die Karte auf die aktuelle Position
void moveToLocation(
    MapController mapController, bool selectedFromList, LatLng point) {
  const zoomLevel = 15.0;
  if (selectedFromList) {
    mapController.move(point, zoomLevel);
  }
}

/// Überprüft und fordert die Standortberechtigung an
Future<int> checkLocationPermission() async {
  var status = await Permission.locationWhenInUse.status;
  if (status.isDenied) {
    status = await Permission.locationWhenInUse.request();
  }
  if (status.isGranted) {
    return 1; // Berechtigung gewährt
  } else {
    return 0; // Berechtigung verweigert
  }
}

const String _favoritesKey = 'favorites';

/// Lädt gespeicherte Favoriten aus SharedPreferences
Future<Set<String>> loadFavorites() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(_favoritesKey)?.toSet() ?? {};
}

/// Speichert die übergebenen Favoriten dauerhaft in SharedPreferences
Future<void> saveFavorites(Set<String> favorites) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(_favoritesKey, favorites.toList());
}

/// Fügt eine ID zu den Favoriten hinzu oder entfernt sie
Future<Set<String>> toggleFavorite(
    Set<String> currentFavorites, String id) async {
  final updated = Set<String>.from(currentFavorites);
  if (updated.contains(id)) {
    updated.remove(id);
  } else {
    updated.add(id);
  }

  await saveFavorites(updated);
  return updated;
}

/// Prüft, ob eine ID ein Favorit ist
bool isFavorite(Set<String> favorites, String id) {
  return favorites.contains(id);
}

/// Speichert die ausgewählte Ladegeschwindigkeit (immer den KEY!)
Future<void> saveSelectedSpeed(String speed) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_selectedSpeedKey, speed);
}

/// Speichert die ausgewählten Stecker
Future<void> saveSelectedPlugs(Set<String> plugs) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(_selectedPlugsKey, plugs.toList());
}

/// Lädt die gespeicherte Ladegeschwindigkeit (immer den KEY zurückgeben!)
Future<String> loadSelectedSpeed() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_selectedSpeedKey) ??
      'all'; // Default = KEY, nicht Label
}

/// Lädt die gespeicherten Stecker
Future<Set<String>> loadSelectedPlugs() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(_selectedPlugsKey)?.toSet() ?? {};
}

/// Formatiert den Technischen Begriff zum geläufigen Namen
String formatPlugType(String plugType) {
  switch (plugType) {
    case 'IEC_62196_T2':
      return 'Typ2';
    case 'IEC_62196_T2_COMBO':
      return 'CCS';
    case 'CHADEMO':
      return 'ChaDeMo';
    case 'IEC_80005_3':
      return 'IEC_80005_3';
    default:
      return plugType;
  }
}

IconData getPlugIcon(String plugType) {
  switch (plugType) {
    case 'IEC_62196_T2':
      return Icons.ev_station; // Typ 2
    case 'IEC_62196_T2_COMBO':
      return Icons.flash_on; // CCS
    case 'CHADEMO':
      return Icons.power; // CHAdeMO
    default:
      return Icons.device_unknown;
  }
}

List<ChargingStationInfo> filterStations({
  required List<ChargingStationInfo> allStations,
  required String selectedSpeed,
  required Set<String> selectedPlugs,
  bool hasParkingSensor = false,
}) {
  final mappedPlugs = selectedPlugs.map((p) => plugTypeMap[p] ?? p).toSet();

  return allStations.where((station) {
    if (hasParkingSensor) {
      // Nur Stationen mit mindestens EINEM EVSE, wo parking_sensor ein Objekt ist
      final hasSensor = station.evses.values.any(
          (evse) => evse.parkingSensor != null && evse.parkingSensor is! bool);
      if (!hasSensor) return false;
    }

    return station.evses.values.any((evse) {
      final plugMatches =
          mappedPlugs.isEmpty || mappedPlugs.contains(evse.chargingPlug);
      final speedMatches = selectedSpeed == 'all' ||
          (selectedSpeed == 'upto_50' && evse.maxPower <= 50) ||
          (selectedSpeed == 'from_50' && evse.maxPower >= 50) ||
          (selectedSpeed == 'from_100' && evse.maxPower >= 100) ||
          (selectedSpeed == 'from_200' && evse.maxPower >= 200) ||
          (selectedSpeed == 'from_300' && evse.maxPower >= 300);

      return plugMatches && speedMatches;
    });
  }).toList();
}

/// Prüft, ob eine Station mindestens einen EVSE hat, der zum Filter passt UND verfügbar ist
/// (NUR MIT KEYS für selectedSpeed! Und optional mit Parksensor)
bool isMatchingAndAvailableEvse(
  ChargingStationInfo station,
  String selectedSpeed,
  Set<String> selectedPlugs, {
  bool hasParkingSensor = false,
}) {
  if (hasParkingSensor) {
    final hasSensor = station.evses.values.any((evse) =>
        evse.hasParkingSensor == true &&
        evse.parkingSensor?.sensorIssue != true);
    if (!hasSensor) return false;
  }

  final mappedPlugs = selectedPlugs.map((p) => plugTypeMap[p] ?? p).toSet();

  for (final evse in station.evses.values) {
    final plugMatches =
        mappedPlugs.isEmpty || mappedPlugs.contains(evse.chargingPlug);
    final speedMatches = selectedSpeed == 'all' ||
        (selectedSpeed == 'upto_50' && evse.maxPower <= 50) ||
        (selectedSpeed == 'from_50' && evse.maxPower >= 50) ||
        (selectedSpeed == 'from_100' && evse.maxPower >= 100) ||
        (selectedSpeed == 'from_200' && evse.maxPower >= 200) ||
        (selectedSpeed == 'from_300' && evse.maxPower >= 300);

    final available = evse.status == 'AVAILABLE';

    bool canUse = false;
    if (evse.hasParkingSensor == true && evse.parkingSensor != null) {
      // Sensor-Defekt? → wie Ladesäule ohne Sensor behandeln!
      if (evse.parkingSensor!.sensorIssue == true) {
        canUse = available;
      } else {
        // Sensor funktioniert → ZUSÄTZLICH illegal geparkt prüfen!
        canUse = available && evse.illegallyParked == false;
      }
    } else {
      // Kein Sensor → Nur Status zählt!
      canUse = available;
    }

    if (plugMatches && speedMatches && canUse) {
      return true;
    }
  }
  return false;
}

/// Entfernt einen Favoriten aus dem Set und speichert es persistent ab
Future<Set<String>> deleteFavorite(
    Set<String> currentFavorites, String stationId) async {
  final prefs = await SharedPreferences.getInstance();
  final updatedFavorites = Set<String>.from(currentFavorites)
    ..remove(stationId);
  await prefs.setStringList('favoriteIds', updatedFavorites.toList());
  return updatedFavorites;
}

Future<void> saveSelectedParkingSensor(bool hasSensor) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_selectedParkingSensorKey, hasSensor);
}

Future<bool> loadSelectedParkingSensor() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_selectedParkingSensorKey) ?? false;
}

/// Lädt die gespeicherten Filter-Einstellungen für den Startbildschirm.
/// Gibt ein Map zurück mit allen Werten.
Future<Map<String, dynamic>> loadInitialFilterSettings() async {
  final selectedSpeed = await loadSelectedSpeed();
  final selectedPlugs = await loadSelectedPlugs();
  final hasParkingSensor = await loadSelectedParkingSensor();
  return {
    'selectedSpeed': selectedSpeed,
    'selectedPlugs': selectedPlugs,
    'hasParkingSensor': hasParkingSensor,
  };
}
