// Created 14.03.2024 by Christopher Schilling
//
// Builds the Favorites Overlay
//
// __version__ = "2.0.0"
//
// __author__ = "Christopher Schilling"

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:charging_station/models/api.dart';
import 'package:charging_station/utils/helper.dart';
import 'package:easy_localization/easy_localization.dart';

/// A widget that builds the Favorites Overlay.
///
/// This widget displays a list of the user's favorite charging stations. It includes
/// the ability to select a station, remove it from favorites, and see the station's
/// available chargers and distance from the user's current location.
class FavoritesOverlay extends StatelessWidget {
  final List<ChargingStationInfo> favoriteStations;
  final Function(ChargingStationInfo) onStationSelected;
  final VoidCallback onClose;
  final Position? currentPosition;
  final List<ChargingStationInfo> chargingStations;
  final Function(String) onDeleteFavorite;

  /// Constructor for the [FavoritesOverlay] widget.
  ///
  /// [favoriteStations] - The list of favorite charging stations.
  /// [onStationSelected] - Callback for when a station is selected.
  /// [onClose] - Callback for when the overlay should be closed.
  /// [currentPosition] - The current position of the user.
  /// [chargingStations] - The list of all charging stations.
  /// [onDeleteFavorite] - Callback for deleting a favorite.
  const FavoritesOverlay({
    super.key,
    required this.favoriteStations,
    required this.onStationSelected,
    required this.onClose,
    required this.currentPosition,
    required this.chargingStations,
    required this.onDeleteFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF282828),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _buildHeader(context),
            _buildFavoritesList(context),
          ],
        ),
      ),
    );
  }

  /// Builds the header of the overlay with the title and close button.
  ///
  /// [context] - The BuildContext used to find localized strings.
  ///
  /// Returns a Padding widget that contains the header.
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 32.0,
        left: 16.0,
        right: 16.0,
        bottom: 8.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'favorites'.tr(),
                style: const TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB2BEB5),
                ),
              ),
              IconButton(
                icon:
                    const Icon(Icons.close, color: Color(0xFFB2BEB5), size: 28),
                onPressed: onClose,
              ),
            ],
          ),
          const Divider(
            color: Color(0xFFB2BEB5),
            thickness: 1.0,
          ),
        ],
      ),
    );
  }

  /// Builds the list of favorite charging stations.
  ///
  /// [context] - The BuildContext used to find localized strings.
  ///
  /// Returns a list view of the favorite stations or a message if there are no favorites.
  Widget _buildFavoritesList(BuildContext context) {
    return Expanded(
      child: favoriteStations.isEmpty
          ? Center(
              child: Text(
                'no_favorites'.tr(),
                style: const TextStyle(color: Color(0xFFB2BEB5), fontSize: 18),
              ),
            )
          : ListView.builder(
              itemCount: favoriteStations.length,
              itemBuilder: (BuildContext context, int index) {
                final ChargingStationInfo station = favoriteStations[index];

                int availableCount = station.evses.values
                    .where((EvseInfo evse) => evse.status == 'AVAILABLE')
                    .length;

                String subtitleText = '';
                if (currentPosition != null) {
                  double distance = calculateDistance(
                    currentPosition!,
                    station.coordinates,
                  );
                  subtitleText = '${formatDistance(distance)} ${"away".tr()}, ';
                }

                // Show number of available chargers or specific text for exactly 1 or 0 chargers
                if (availableCount == 1) {
                  subtitleText += 'one_charger_available'
                      .tr(); // Localized text for "one charger available"
                } else {
                  subtitleText +=
                      '$availableCount ${"chargers_available".tr()}';
                }

                return Column(
                  children: <Widget>[
                    if (index > 0) ...<Widget>[
                      const Divider(
                        color: Color(0xFFB2BEB5),
                        thickness: 1.0,
                        height: 0,
                      ),
                      const SizedBox(height: 14),
                    ],
                    ListTile(
                      title: Text(
                        station.address,
                        style: const TextStyle(
                          fontSize: 21.0,
                          color: Color(0xFFB2BEB5),
                        ),
                      ),
                      subtitle: Text(
                        subtitleText,
                        style: const TextStyle(
                          fontSize: 18.0,
                          color: Color(0xFFB2BEB5),
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close,
                            color: Color(0xFFB2BEB5), size: 26),
                        onPressed: () =>
                            onDeleteFavorite(station.id.toString()),
                        tooltip: 'remove_favorite'.tr(),
                      ),
                      onTap: () {
                        onStationSelected(station);
                        onClose();
                      },
                    ),
                  ],
                );
              },
            ),
    );
  }
}
