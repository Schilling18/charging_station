// Created 14.03.2024 by Christopher Schilling
//
// This file builds the MapScreen Widget.
//
// __version__ = "1.0.0"
//
// __author__ = "Christopher Schilling"
//

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

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  MapScreenState createState() => MapScreenState();
}

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

  // --- Daten/Favoriten/Filter ---
  List<ChargingStationInfo> chargingStations = [];
  List<ChargingStationInfo> filteredStations = [];
  Set<String> favoriteIds = {};
  Set<String> selectedPlugs = {};
  String selectedSpeed = 'all';

  List<Marker> _markers = [];

  // --- Controller für Suchfeld ---
  late final TextEditingController searchController;

  final LatLng defaultCoordinates = const LatLng(52.3906, 13.0645); // Potsdam

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController();
    selectedCoordinates = defaultCoordinates;
    _loadCurrentPosition();
    _loadChargingStationsAndFavorites();
    loadInitialFilterSettings();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      setState(() {
        currentPosition = position;
        selectedCoordinates = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      // Fehlerbehandlung (optional: Snackbar, Log)
    }
  }

  Future<void> _loadChargingStationsAndFavorites() async {
    try {
      final stations = await ApiService().fetchChargingStations();
      final favs = await loadFavorites();
      setState(() {
        chargingStations = stations;
        favoriteIds = favs;
      });

      // Lade gespeicherte Filter und filtere!
      final filterSettings = await loadInitialFilterSettings();
      final filtered = filterStations(
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
        chargingStations = [];
        favoriteIds = {};
      });
    }
  }

  void _onStationSelected(ChargingStationInfo station) {
    setState(() {
      selectedCoordinates = station.coordinates;
      selectedStation = station;
      selectedFromList = true;
      showFavoritesOverlay = false;
    });
  }

  void updateMarkersFromFilteredStations() {
    final newMarkers = filteredStations
        .map((station) {
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
                    ? Colors.green
                    : Colors.grey,
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
    final favoriteStations = chargingStations
        .where((station) => isFavorite(favoriteIds, station.id.toString()))
        .toList();

    return Scaffold(
      body: isOverlayVisible
          ? _buildSearchOverlay()
          : Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: selectedCoordinates ?? defaultCoordinates,
                    initialZoom: 13.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                      subdomains: const ['a', 'b', 'c'],
                    ),
                    MarkerLayer(
                      markers: _markers,
                    ),
                  ],
                ),
                Positioned(
                  top: 40,
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
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 5.0,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
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
                    onApply: (newSpeed, newPlugs, hasParkingSensor) async {
                      final filtered = filterStations(
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
                      onVerticalDragUpdate: (details) {
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
                        onDismissed: (direction) {
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
                          toggleFavorite: (stationId) async {
                            final updated =
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
        onDeleteFavorite: (stationId) async {
          final updated = await deleteFavorite(favoriteIds, stationId);
          setState(() {
            favoriteIds = updated;
          });
        },
      );

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
  Widget _buildSearchOverlay() => SearchOverlay(
        filteredStations: filteredStations,
        searchController: searchController,
        currentPosition: currentPosition,
        onClose: () {
          setState(() {
            isOverlayVisible = false;
          });
        },
        onStationSelected: (station) {
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
        // Die drei Filter-Werte übergeben!
        selectedSpeed: selectedSpeed,
        selectedPlugs: selectedPlugs,
        hasParkingSensor: filteredHasParkingSensor,
      );
}
