// Created 14.03.2024 by Christopher Schilling
//
// The file stores logic functions, which are used across the project.
//
// __version__ = "2.0.0"
//
// __author__ = "Christopher Schilling"

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

const Map<String, String> plugTypeMap = <String, String>{
  'Typ2': 'IEC_62196_T2',
  'CCS': 'IEC_62196_T2_COMBO',
  'CHAdeMO': 'CHADEMO',
  'Tesla': 'TESLA',
};

/// Calculates the distance between the current position and a charging station.
///
/// This function uses the Geolocator package to compute the distance between two geographical points.
///
/// [currentPosition] - The current position of the device (latitude and longitude).
/// [stationPosition] - The position of the charging station (LatLng, latitude and longitude).
///
/// Returns the distance in kilometers between the two points.
double calculateDistance(Position currentPosition, LatLng stationPosition) {
  double distanceInMeters = Geolocator.distanceBetween(
    currentPosition.latitude,
    currentPosition.longitude,
    stationPosition.latitude,
    stationPosition.longitude,
  );
  return distanceInMeters / 1000;
}

/// Formats the distance to the charging station.
///
/// [distance] - The distance in kilometers.
///
/// Returns a formatted string that shows the distance either in meters (if < 1 km) or in kilometers.
String formatDistance(double distance) {
  if (distance < 1) {
    return '${(distance * 1000).toStringAsFixed(0)} m';
  } else {
    return '${distance.toStringAsFixed(2)} km';
  }
}

/// Displays a dialog if the location permission is denied.
///
/// [context] - The BuildContext to display the dialog.
void showPermissionDeniedDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Location Permission Denied'),
        content: const Text(
            'In order to display nearby charging stations correctly, location access is required. You can change this in the settings.'),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

/// Moves the map to the current position if it was selected from a list.
///
/// [mapController] - The controller of the map to move the map.
/// [selectedFromList] - Indicates whether the position was selected from a list.
/// [point] - The target position (LatLng) to move the map to.
void moveToLocation(
    MapController mapController, bool selectedFromList, LatLng point) {
  const double zoomLevel = 15.0;
  if (selectedFromList) {
    mapController.move(point, zoomLevel);
  }
}

/// Checks and requests the location permission.
///
/// Returns: 1 if the permission is granted, otherwise 0.
Future<int> checkLocationPermission() async {
  PermissionStatus status = await Permission.locationWhenInUse.status;
  if (status.isDenied) {
    status = await Permission.locationWhenInUse.request();
  }
  if (status.isGranted) {
    return 1;
  } else {
    return 0;
  }
}

const String _favoritesKey = 'favorites';

/// Loads saved favorites from SharedPreferences.
///
/// Returns: A set of favorite IDs.
Future<Set<String>> loadFavorites() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(_favoritesKey)?.toSet() ?? <String>{};
}

/// Saves the given favorites persistently in SharedPreferences.
///
/// [favorites] - A set of favorite IDs to be saved.
Future<void> saveFavorites(Set<String> favorites) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(_favoritesKey, favorites.toList());
}

/// Adds or removes an ID from the favorites list.
///
/// [currentFavorites] - The current set of favorites.
/// [id] - The ID to be added or removed.
///
/// Returns: The updated set of favorites.
Future<Set<String>> toggleFavorite(
    Set<String> currentFavorites, String id) async {
  final Set<String> updated = Set<String>.from(currentFavorites);
  if (updated.contains(id)) {
    updated.remove(id);
  } else {
    updated.add(id);
  }

  await saveFavorites(updated);
  return updated;
}

/// Checks if an ID is a favorite.
///
/// [favorites] - The set of favorites.
/// [id] - The ID to be checked.
///
/// Returns: True if the ID is a favorite, otherwise False.
bool isFavorite(Set<String> favorites, String id) {
  return favorites.contains(id);
}

/// Saves the selected charging speed.
///
/// [speed] - The selected charging speed to be saved.
Future<void> saveSelectedSpeed(String speed) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString(_selectedSpeedKey, speed);
}

/// Saves the selected plug types.
///
/// [plugs] - A set of selected plug types to be saved.
Future<void> saveSelectedPlugs(Set<String> plugs) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(_selectedPlugsKey, plugs.toList());
}

/// Loads the saved charging speed.
///
/// Returns: The saved charging speed, or the default value 'all' if none is saved.
Future<String> loadSelectedSpeed() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getString(_selectedSpeedKey) ?? 'all';
}

/// Loads the saved plug types.
///
/// Returns: A set of saved plug types.
Future<Set<String>> loadSelectedPlugs() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(_selectedPlugsKey)?.toSet() ?? <String>{};
}

/// Formats the technical term for the plug type into a more common name.
///
/// [plugType] - The technical term for the plug (e.g., 'IEC_62196_T2').
///
/// Returns: The more common name of the plug type (e.g., 'Typ2').
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

/// Returns the appropriate icon for the plug type.
///
/// [plugType] - The plug type.
///
/// Returns: The appropriate icon for the plug type.
IconData getPlugIcon(String plugType) {
  switch (plugType) {
    case 'IEC_62196_T2':
      return Icons.ev_station; // Typ 2
    case 'IEC_62196_T2_COMBO':
      return Icons.flash_on; // CCS
    case 'CHADEMO':
      return Icons.power; // CHAdeMO
    default:
      return Icons.device_unknown; // Unknown plug type
  }
}

/// Filters charging stations based on the selected filters (charging speed, plug types, etc.)
///
/// [allStations] - The list of all charging stations to be filtered.
/// [selectedSpeed] - The selected charging speed (e.g., 'upto_50' for up to 50 kW).
/// [selectedPlugs] - The selected plug types.
/// [hasParkingSensor] - An optional filter to include stations with or without parking sensors.
///
/// Returns: A filtered list of charging stations that match the given criteria.
List<ChargingStationInfo> filterStations({
  required List<ChargingStationInfo> allStations,
  required String selectedSpeed,
  required Set<String> selectedPlugs,
  bool hasParkingSensor = false,
}) {
  final Set<String> mappedPlugs =
      selectedPlugs.map((String p) => plugTypeMap[p] ?? p).toSet();

  return allStations.where((ChargingStationInfo station) {
    if (hasParkingSensor) {
      final bool hasSensor = station.evses.values.any((EvseInfo evse) =>
          evse.parkingSensor != null && evse.parkingSensor is! bool);
      if (!hasSensor) return false;
    }

    return station.evses.values.any((EvseInfo evse) {
      final bool plugMatches =
          mappedPlugs.isEmpty || mappedPlugs.contains(evse.chargingPlug);
      final bool speedMatches = selectedSpeed == 'all' ||
          (selectedSpeed == 'upto_50' && evse.maxPower <= 50) ||
          (selectedSpeed == 'from_50' && evse.maxPower >= 50) ||
          (selectedSpeed == 'from_100' && evse.maxPower >= 100) ||
          (selectedSpeed == 'from_200' && evse.maxPower >= 200) ||
          (selectedSpeed == 'from_300' && evse.maxPower >= 300);

      return plugMatches && speedMatches;
    });
  }).toList();
}

/// Checks if a station has at least one EVSE that matches the filter and is available
/// (only with keys for selectedSpeed! And optionally with parking sensor)
///
/// [station] - The charging station to check.
/// [selectedSpeed] - The selected charging speed.
/// [selectedPlugs] - The selected plug types.
/// [hasParkingSensor] - An optional filter to include stations with or without parking sensors.
///
/// Returns: True if a matching and available EVSE is found, otherwise False.
bool isMatchingAndAvailableEvse(
  ChargingStationInfo station,
  String selectedSpeed,
  Set<String> selectedPlugs, {
  bool hasParkingSensor = false,
}) {
  if (hasParkingSensor) {
    final bool hasSensor = station.evses.values.any((EvseInfo evse) =>
        evse.hasParkingSensor == true &&
        evse.parkingSensor?.sensorIssue != true);
    if (!hasSensor) return false;
  }

  final Set<String> mappedPlugs =
      selectedPlugs.map((String p) => plugTypeMap[p] ?? p).toSet();

  for (final EvseInfo evse in station.evses.values) {
    final bool plugMatches =
        mappedPlugs.isEmpty || mappedPlugs.contains(evse.chargingPlug);
    final bool speedMatches = selectedSpeed == 'all' ||
        (selectedSpeed == 'upto_50' && evse.maxPower <= 50) ||
        (selectedSpeed == 'from_50' && evse.maxPower >= 50) ||
        (selectedSpeed == 'from_100' && evse.maxPower >= 100) ||
        (selectedSpeed == 'from_200' && evse.maxPower >= 200) ||
        (selectedSpeed == 'from_300' && evse.maxPower >= 300);

    final bool available = evse.status == 'AVAILABLE';

    bool canUse = false;
    if (evse.hasParkingSensor == true && evse.parkingSensor != null) {
      // Sensor defect? → Treat like a station without a sensor
      if (evse.parkingSensor!.sensorIssue == true) {
        canUse = available;
      } else {
        // Sensor works → Additionally check if illegally parked
        canUse = available && evse.illegallyParked == false;
      }
    } else {
      // No sensor → Only status matters
      canUse = available;
    }

    if (plugMatches && speedMatches && canUse) {
      return true;
    }
  }
  return false;
}

/// Removes a favorite from the set and saves it persistently.
///
/// [currentFavorites] - The current set of favorite IDs.
/// [stationId] - The ID of the station to remove.
///
/// Returns: The updated set of favorite IDs.
Future<Set<String>> deleteFavorite(
    Set<String> currentFavorites, String stationId) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final Set<String> updatedFavorites = Set<String>.from(currentFavorites)
    ..remove(stationId);
  await prefs.setStringList('favoriteIds', updatedFavorites.toList());
  return updatedFavorites;
}

/// Saves the selected parking sensor status.
///
/// [hasSensor] - A boolean value indicating whether the parking sensor is enabled (true) or disabled (false).
/// This value will be stored in SharedPreferences.
///
/// This function doesn't return any value, it simply saves the information persistently.
Future<void> saveSelectedParkingSensor(bool hasSensor) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_selectedParkingSensorKey, hasSensor);
}

/// Loads the saved parking sensor status.
///
/// Returns: A boolean indicating whether the parking sensor is enabled (true) or disabled (false).
/// If no value is saved, it will return false by default.
Future<bool> loadSelectedParkingSensor() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_selectedParkingSensorKey) ?? false;
}

/// Loads the saved filter settings for the start screen.
/// Returns a map with all values.
///
/// Returns: A map with the initial filter settings (charging speed, plug types, parking sensor).
Future<Map<String, dynamic>> loadInitialFilterSettings() async {
  final String selectedSpeed = await loadSelectedSpeed();
  final Set<String> selectedPlugs = await loadSelectedPlugs();
  final bool hasParkingSensor = await loadSelectedParkingSensor();
  return <String, dynamic>{
    'selectedSpeed': selectedSpeed,
    'selectedPlugs': selectedPlugs,
    'hasParkingSensor': hasParkingSensor,
  };
}

/// Fetches fresh charging stations, favorites, and filtered stations based on saved filter settings.
/// This method is intended to be used for periodic background refreshes.
///
/// Returns: A map containing updated stations, favorites, filter values, and filtered results.
Future<Map<String, dynamic>> fetchUpdatedStationData() async {
  final List<ChargingStationInfo> newStations =
      await ApiService().fetchChargingStations();

  final Set<String> newFavorites = await loadFavorites();

  final Map<String, dynamic> newFilterSettings =
      await loadInitialFilterSettings();

  final List<ChargingStationInfo> newFiltered = filterStations(
    allStations: newStations,
    selectedSpeed: newFilterSettings['selectedSpeed'] as String,
    selectedPlugs: newFilterSettings['selectedPlugs'] as Set<String>,
    hasParkingSensor: newFilterSettings['hasParkingSensor'] as bool,
  );

  return <String, dynamic>{
    'stations': newStations,
    'favorites': newFavorites,
    'filteredStations': newFiltered,
    'selectedSpeed': newFilterSettings['selectedSpeed'],
    'selectedPlugs': newFilterSettings['selectedPlugs'],
    'hasParkingSensor': newFilterSettings['hasParkingSensor'],
  };
}
