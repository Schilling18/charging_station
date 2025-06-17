// Created 20.03.2024 by Christopher Schilling
// Last Modified 21.05.2025
//
// The file converts and filters the information from the API
// into a usable entity
//
// __version__ = "2.0.0"
// __author__ = "Christopher Schilling"

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Class for detailed Parking Sensor Status (if present).
class ParkingSensorStatus {
  final String status;
  final bool illegallyParked;
  final bool sensorIssue;
  final String utcLastStateChange;

  ParkingSensorStatus({
    required this.status,
    required this.illegallyParked,
    required this.sensorIssue,
    required this.utcLastStateChange,
  });

  factory ParkingSensorStatus.fromJson(Map<String, dynamic> json) {
    return ParkingSensorStatus(
      status: json['status'] ?? '',
      illegallyParked: json['illegally_parked'] ?? false,
      sensorIssue: json['sensor_issue'] ?? false,
      utcLastStateChange: json['utc_last_state_change'] ?? '',
    );
  }
}

/// Class representing an Electric Vehicle Supply Equipment (EVSE).
class EvseInfo {
  final String evseNumber;
  final int maxPower;
  final String status;
  final bool illegallyParked;
  final String chargingPlug;
  final ParkingSensorStatus? parkingSensor; // null wenn kein Sensor
  final bool hasParkingSensor; // true = Sensor vorhanden, false = kein Sensor

  EvseInfo({
    required this.evseNumber,
    required this.maxPower,
    required this.status,
    required this.illegallyParked,
    required this.chargingPlug,
    this.parkingSensor,
    this.hasParkingSensor = false,
  });
}

/// Class representing a Charging Station.
class ChargingStationInfo {
  final String id;
  final String address;
  final String city;
  final LatLng coordinates;
  final int freechargers;
  final Map<String, EvseInfo> evses;

  ChargingStationInfo({
    required this.id,
    required this.address,
    required this.city,
    required this.coordinates,
    required this.freechargers,
    required this.evses,
  });

  /// Factory constructor to create an instance of ChargingStationInfo from JSON
  factory ChargingStationInfo.fromJson(Map<String, dynamic> json) {
    final Map<String, EvseInfo> evsesMap =
        <String, EvseInfo>{}; // explizit typisiert
    final Set<String> uniqueAvailableEvseNumbers =
        <String>{}; // explizit typisiert

    for (final dynamic evse in json['evses']) {
      for (final dynamic connector in evse['connectors']) {
        bool illegallyParked = false;
        final String status = evse['status'];

        ParkingSensorStatus? parkingSensorStatus;
        bool hasParkingSensor = false;

        if (evse.containsKey('parking_sensor')) {
          final dynamic ps = evse['parking_sensor'];

          if (ps == false) {
            parkingSensorStatus = null;
            hasParkingSensor = false;
            illegallyParked = false;
          } else if (ps is Map<String, dynamic>) {
            parkingSensorStatus = ParkingSensorStatus.fromJson(ps);
            hasParkingSensor = true;
            illegallyParked = ps['illegally_parked'] ?? false;
          }
        }

        if (status == 'AVAILABLE' && !illegallyParked) {
          uniqueAvailableEvseNumbers.add(evse['id']);
        }

        evsesMap[evse['id']] = EvseInfo(
          evseNumber: evse['id'],
          maxPower: connector['max_power'],
          status: status,
          illegallyParked: illegallyParked,
          chargingPlug: connector['standard'],
          parkingSensor: parkingSensorStatus,
          hasParkingSensor: hasParkingSensor,
        );
      }
    }

    return ChargingStationInfo(
      id: json['id'],
      address: json['address'],
      city: json['city'],
      coordinates: LatLng(
        double.parse(json['coordinates']['latitude']),
        double.parse(json['coordinates']['longitude']),
      ),
      freechargers: uniqueAvailableEvseNumbers.length,
      evses: evsesMap,
    );
  }
}

/// Service class for API interactions.
class ApiService {
  final String baseUrl = dotenv.env['API_BASE_URL']!;
  final String apiKey = dotenv.env['API_KEY']!;

  /// Fetches the list of charging stations from the API.
  Future<List<ChargingStationInfo>> fetchChargingStations() async {
    final http.Response response = await http.get(
      Uri.parse(baseUrl),
      headers: <String, String>{'X-Api-Key': apiKey},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);

      if (data.containsKey('data')) {
        final List<dynamic> stations = data['data'] as List<dynamic>;

        return stations
            .map((dynamic station) =>
                ChargingStationInfo.fromJson(station as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('No data key found in response');
      }
    } else {
      throw Exception('Failed to load charging stations');
    }
  }

  /// Searches for an address using the OpenStreetMap Nominatim API.
  Future<List<dynamic>> searchAddress(String query) async {
    final http.Response response = await http.get(Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=1&countrycodes=de'));
    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>; // explizit typisiert
    } else {
      throw Exception('Error: ${response.reasonPhrase}, No API connection ');
    }
  }
}

/// Used for debugging.
Future<void> main() async {
  await dotenv.load();
  final ApiService apiService = ApiService();
  try {
    final List<ChargingStationInfo> stations =
        await apiService.fetchChargingStations();
    for (final dynamic station in stations) {
      if (kDebugMode) {
        debugPrint('ID: ${station.id}');
        debugPrint('Address: ${station.address}');
        debugPrint('City: ${station.city}');
        debugPrint(
            'Coordinates: ${station.coordinates.latitude}, ${station.coordinates.longitude}');
        debugPrint('Free Chargers: ${station.freechargers}');
        debugPrint('EVSEs:');
        for (final dynamic evse in station.evses.values) {
          debugPrint('  EVSE Number: ${evse.evseNumber}');
          debugPrint('  Max Power: ${evse.maxPower}');
          debugPrint('  Status: ${evse.status}');
          debugPrint('  Illegally Parked: ${evse.illegallyParked}');
          debugPrint('  Charging Plug: ${evse.chargingPlug}');
          debugPrint('  Has Parking Sensor: ${evse.hasParkingSensor}');
          if (evse.parkingSensor != null) {
            debugPrint('    - Sensor Status: ${evse.parkingSensor!.status}');
            debugPrint(
                '    - Illegally Parked: ${evse.parkingSensor!.illegallyParked}');
            debugPrint(
                '    - Sensor Issue: ${evse.parkingSensor!.sensorIssue}');
            debugPrint(
                '    - Last State Change: ${evse.parkingSensor!.utcLastStateChange}');
          }
        }
      }
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Error: $e');
    }
  }
}
