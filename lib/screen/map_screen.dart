// Created 14.03.2024 by Christopher Schilling
//
// This file defines the MapScreen widget that displays a map with charging stations,
// handles search functionality, displays charging station details, and manages overlays.
//
// __version__ = "2.0.1"
//
// __author__ = "Christopher Schilling"

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:charging_station/widgets/bottom_bar.dart';
import 'package:charging_station/widgets/search_overlay.dart';
import 'package:charging_station/widgets/favorites_overlay.dart';
import 'package:charging_station/widgets/station_details.dart';
import 'package:charging_station/widgets/filter_overlay.dart';
import 'package:charging_station/widgets/settings_overlay.dart';
import 'package:charging_station/models/api.dart';
import 'package:charging_station/utils/helper.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:async';

/// A widget representing the map screen where users can interact with the map,
/// view charging stations, search for stations, and apply filters.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  MapScreenState createState() => MapScreenState();
}

/// The state class for the [MapScreen] widget, which manages the map display,
/// overlays, user interactions, and dynamic data updates.
///
/// This class handles user interactions with the map such as selecting stations,
/// searching, applying filters, and viewing station details. It also fetches
/// updated data periodically to ensure station information is always current.
///
/// Overlay states:
/// [isOverlayVisible] - Controls visibility of the search overlay.
/// [showFavoritesOverlay] - Controls visibility of the favorites overlay.
/// [selectedFromList] - Indicates whether a station was selected from a list (vs map).
/// [showFilterOverlay] - Controls visibility of the filter overlay.
/// [showSettingsOverlay] - Controls visibility of the settings overlay.
/// [filteredHasParkingSensor] - Current filter state for parking sensor availability.
///
/// Map and position state:
/// [currentPosition] - The current geolocation of the user.
/// [selectedCoordinates] - The coordinates to which the map is currently centered.
/// [selectedStation] - The currently selected charging station (from map or list).
///
/// Data and filter state:
/// [chargingStations] - The full list of charging stations from the API.
/// [filteredStations] - A subset of [chargingStations] based on user filters.
/// [favoriteIds] - A set of station IDs marked as user favorites.
/// [selectedPlugs] - The currently selected plug types for filtering.
/// [selectedSpeed] - The selected charging speed filter (e.g., 'from_50').
/// [_refreshTimer] - Internal timer that triggers data refresh every 60 seconds.
/// [_markers] - The current list of map markers representing filtered stations.
///
/// Controller:
/// [searchController] - The controller tied to the search text field.
/// [_mapController] - The controller for the FlutterMap widget to programmatically move or zoom.
///
/// [defaultCoordinates] - The fallback/default map center (Potsdam) if user location is not available.
class MapScreenState extends State<MapScreen> {
  // --- Overlay States ---
  bool isOverlayVisible = false;
  bool showFavoritesOverlay = false;
  bool selectedFromList = false;
  bool showFilterOverlay = false;
  bool showSettingsOverlay = false;
  bool filteredHasParkingSensor = false;

  // --- Map/Position ---
  Position? currentPosition;
  LatLng? selectedCoordinates;
  ChargingStationInfo? selectedStation;

  // --- Data/Favorites/Filter ---
  List<ChargingStationInfo> chargingStations = <ChargingStationInfo>[];
  List<ChargingStationInfo> filteredStations = <ChargingStationInfo>[];
  Set<String> favoriteIds = <String>{};
  Set<String> selectedPlugs = <String>{};
  String selectedSpeed = 'all';
  Timer? _refreshTimer;
  List<Marker> _markers = <Marker>[];

  // --- Controller for Search Field ---
  late final TextEditingController searchController;
  final MapController _mapController = MapController();

  final LatLng defaultCoordinates =
      const LatLng(52.3906, 13.0645); // Default map coordinates (Potsdam)

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController();
    selectedCoordinates = defaultCoordinates;
    _loadCurrentPosition();
    _loadChargingStationsAndFavorites();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _refreshChargingStations(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    searchController.dispose();
    super.dispose();
  }

  /// Loads the user's current position using Geolocator.
  Future<void> _loadCurrentPosition() async {
    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      setState(() {
        currentPosition = position;
        selectedCoordinates = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      //WIP
    }
  }

  /// Loads charging stations, favorites, and applies filters.
  Future<void> _loadChargingStationsAndFavorites() async {
    try {
      final List<ChargingStationInfo> stations =
          await ApiService().fetchChargingStations();
      final Set<String> favs = await loadFavorites();
      setState(() {
        chargingStations = stations;
        favoriteIds = favs;
      });

      // Load filter settings and apply them to filter the stations
      final Map<String, dynamic> filterSettings =
          await loadInitialFilterSettings();
      final List<ChargingStationInfo> filtered = filterStations(
        allStations: chargingStations,
        selectedSpeed: filterSettings['selectedSpeed'] as String,
        selectedPlugs: filterSettings['selectedPlugs'] as Set<String>,
        hasParkingSensor: filterSettings['hasParkingSensor'] as bool,
      );
      setState(() {
        selectedSpeed = filterSettings['selectedSpeed'] as String;
        selectedPlugs = filterSettings['selectedPlugs'] as Set<String>;
        filteredHasParkingSensor = filterSettings['hasParkingSensor'] as bool;
        filteredStations = filtered;
      });
      updateMarkersFromFilteredStations();
    } catch (e) {
      setState(() {
        chargingStations = <ChargingStationInfo>[];
        favoriteIds = <String>{};
      });
    }
  }

  Future<void> _refreshChargingStations() async {
    try {
      final Map<String, dynamic> result = await fetchUpdatedStationData();

      if (!mounted) return;

      setState(() {
        chargingStations = result['stations'] as List<ChargingStationInfo>;
        favoriteIds = result['favorites'] as Set<String>;
        filteredStations =
            result['filteredStations'] as List<ChargingStationInfo>;
        selectedSpeed = result['selectedSpeed'] as String;
        selectedPlugs = result['selectedPlugs'] as Set<String>;
        filteredHasParkingSensor = result['hasParkingSensor'] as bool;
      });

      updateMarkersFromFilteredStations();
    } catch (e) {
      debugPrint('Error during auto-refresh: $e');
    }
  }

  /// Handles the station selection and updates the selected station details.
  void _onStationSelected(ChargingStationInfo station) {
    setState(() {
      selectedCoordinates = station.coordinates;
      selectedStation = station;
      selectedFromList = true;
      showFavoritesOverlay = false;
    });
    _mapController.move(station.coordinates, 19.0);
  }

  /// Updates the markers on the map based on the filtered stations.
  void updateMarkersFromFilteredStations() {
    final List<Marker> newMarkers = filteredStations
        .map((ChargingStationInfo station) {
          if (station.coordinates.latitude.isNaN ||
              station.coordinates.longitude.isNaN) {
            return null;
          }
          return Marker(
            width: 40,
            height: 40,
            point: station.coordinates,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedCoordinates = station.coordinates;
                  selectedStation = station;
                  selectedFromList = false;
                });
              },
              child: Icon(
                Icons.location_on,
                size: 40.0,
                color: isMatchingAndAvailableEvse(
                  station,
                  selectedSpeed,
                  selectedPlugs,
                  hasParkingSensor: filteredHasParkingSensor,
                )
                    ? Colors.green // Green for available stations
                    : Colors.grey, // Grey for unavailable stations
              ),
            ),
          );
        })
        .whereType<Marker>()
        .toList();

    if (newMarkers.isEmpty) {
      newMarkers.add(
        const Marker(
          width: 40,
          height: 40,
          point: LatLng(52.52, 13.405),
          child: Icon(Icons.location_on, color: Colors.blue),
        ),
      );
    }

    setState(() {
      _markers = newMarkers;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<ChargingStationInfo> favoriteStations = chargingStations
        .where((ChargingStationInfo station) =>
            isFavorite(favoriteIds, station.id.toString()))
        .toList();

    return Scaffold(
      body: isOverlayVisible
          ? _buildSearchOverlay()
          : Stack(
              children: <Widget>[
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: selectedCoordinates ?? defaultCoordinates,
                    initialZoom: 13.0,
                  ),
                  children: <Widget>[
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const <String>['a', 'b', 'c'],
                    ),
                    MarkerLayer(
                      markers: _markers,
                    ),
                  ],
                ),
                Positioned(
                  top: 80,
                  left: 20,
                  right: 20,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        isOverlayVisible = true;
                        showFavoritesOverlay = false;
                        selectedStation = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 14.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.0),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 5.0,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.search, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            'search'.tr(),
                            style: const TextStyle(
                                color: Colors.black, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (showFavoritesOverlay)
                  _buildFavoritesOverlay(favoriteStations),
                if (showFilterOverlay)
                  FilterOverlay(
                    onClose: () {
                      setState(() {
                        showFilterOverlay = false;
                      });
                    },
                    onApply: (String newSpeed, Set<String> newPlugs,
                        bool hasParkingSensor) async {
                      final List<ChargingStationInfo> filtered = filterStations(
                        allStations: chargingStations,
                        selectedSpeed: newSpeed,
                        selectedPlugs: newPlugs,
                        hasParkingSensor: hasParkingSensor,
                      );
                      setState(() {
                        selectedSpeed = newSpeed;
                        selectedPlugs = newPlugs;
                        filteredStations = filtered;
                        filteredHasParkingSensor = hasParkingSensor;
                        showFilterOverlay = false;
                      });
                      updateMarkersFromFilteredStations();
                    },
                  ),
                if (showSettingsOverlay)
                  SettingsOverlay(
                    onClose: () {
                      setState(() {
                        showSettingsOverlay = false;
                      });
                    },
                  ),
                if (selectedStation != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: GestureDetector(
                      onVerticalDragUpdate: (DragUpdateDetails details) {
                        if (details.primaryDelta! < 0) {
                          setState(() {
                            selectedStation = null;
                            selectedFromList = false;
                          });
                        }
                      },
                      child: Dismissible(
                        key: Key(selectedStation!.id.toString()),
                        direction: DismissDirection.down,
                        onDismissed: (DismissDirection direction) {
                          setState(() {
                            selectedStation = null;
                            selectedFromList = false;
                          });
                        },
                        child: StationDetailsWidget(
                          selectedStation: selectedStation!,
                          currentPosition: currentPosition,
                          isFavorite: isFavorite(
                              favoriteIds, selectedStation!.id.toString()),
                          toggleFavorite: (String stationId) async {
                            final Set<String> updated =
                                await toggleFavorite(favoriteIds, stationId);
                            setState(() {
                              favoriteIds = updated;
                            });
                          },
                          onDismiss: () {
                            setState(() {
                              selectedStation = null;
                              selectedFromList = false;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: isOverlayVisible ||
              selectedStation != null ||
              showFilterOverlay ||
              showFavoritesOverlay ||
              showSettingsOverlay
          ? const SizedBox.shrink()
          : _buildBottomBar(),
    );
  }

  /// Builds the favorites overlay widget to display favorite charging stations.
  Widget _buildFavoritesOverlay(List<ChargingStationInfo> favoriteStations) =>
      FavoritesOverlay(
        favoriteStations: favoriteStations,
        currentPosition: currentPosition,
        onStationSelected: _onStationSelected,
        onClose: () {
          setState(() {
            showFavoritesOverlay = false;
          });
        },
        chargingStations: chargingStations,
        onDeleteFavorite: (String stationId) async {
          final Set<String> updated =
              await deleteFavorite(favoriteIds, stationId);
          setState(() {
            favoriteIds = updated;
          });
        },
      );

  /// Builds the bottom bar widget containing buttons for favorites, settings, and filters.
  Widget _buildBottomBar() => BottomBar(
        onFavoritesTap: () {
          setState(() {
            showFavoritesOverlay = !showFavoritesOverlay;
          });
        },
        onSettingsTap: () {
          setState(() {
            showSettingsOverlay = !showSettingsOverlay;
          });
        },
        onFilterTap: () {
          setState(() {
            showFilterOverlay = !showFilterOverlay;
          });
        },
      );

  /// Builds the search overlay widget for filtering and selecting charging stations.
  Widget _buildSearchOverlay() => SearchOverlay(
        filteredStations: filteredStations,
        searchController: searchController,
        currentPosition: currentPosition,
        onClose: () {
          setState(() {
            isOverlayVisible = false;
          });
        },
        onStationSelected: (ChargingStationInfo station) {
          _onStationSelected(station);
          setState(() {
            isOverlayVisible = false;
          });
        },
        onFilterTap: () {
          setState(() {
            isOverlayVisible = false;
            showFilterOverlay = true;
          });
        },
        selectedSpeed: selectedSpeed,
        selectedPlugs: selectedPlugs,
        hasParkingSensor: filteredHasParkingSensor,
      );
}
