// Created 20.03.2024 by Christopher Schilling
// Last Modified 21.05.2025
//
// The file converts and filters the information from the API
// into a usable entity
//
// __version__ = "1.0.2"
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
    Map<String, EvseInfo> evsesMap = {};
    Set<String> uniqueAvailableEvseNumbers = {};

    for (var evse in json['evses']) {
      for (var connector in evse['connectors']) {
        bool illegallyParked = false;
        String status = evse['status'];

        ParkingSensorStatus? parkingSensorStatus;
        bool hasParkingSensor = false;

        if (evse.containsKey('parking_sensor')) {
          final ps = evse['parking_sensor'];
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
    final response = await http.get(
      Uri.parse(baseUrl),
      headers: {'X-Api-Key': apiKey},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);

      if (data.containsKey('data')) {
        final List<dynamic> stations = data['data'];

        return stations
            .map((station) => ChargingStationInfo.fromJson(station))
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
    final response = await http.get(Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=1&countrycodes=de'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error: ${response.reasonPhrase}, No API connection ');
    }
  }
}

/// Used for debugging.
Future<void> main() async {
  await dotenv.load();
  final apiService = ApiService();
  try {
    final stations = await apiService.fetchChargingStations();
    for (var station in stations) {
      if (kDebugMode) {
        print('ID: ${station.id}');
        print('Address: ${station.address}');
        print('City: ${station.city}');
        print(
            'Coordinates: ${station.coordinates.latitude}, ${station.coordinates.longitude}');
        print('Free Chargers: ${station.freechargers}');
        print('EVSEs:');
        for (var evse in station.evses.values) {
          print('  EVSE Number: ${evse.evseNumber}');
          print('  Max Power: ${evse.maxPower}');
          print('  Status: ${evse.status}');
          print('  Illegally Parked: ${evse.illegallyParked}');
          print('  Charging Plug: ${evse.chargingPlug}');
          print('  Has Parking Sensor: ${evse.hasParkingSensor}');
          if (evse.parkingSensor != null) {
            print('    - Sensor Status: ${evse.parkingSensor!.status}');
            print(
                '    - Illegally Parked: ${evse.parkingSensor!.illegallyParked}');
            print('    - Sensor Issue: ${evse.parkingSensor!.sensorIssue}');
            print(
                '    - Last State Change: ${evse.parkingSensor!.utcLastStateChange}');
          }
        }
      }
      if (kDebugMode) {
        print('---');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error: $e');
    }
  }
}
