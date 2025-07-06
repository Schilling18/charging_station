// Created 14.03.2024 by Christopher Schilling
//
// This file builds the SearchOverlay widget that allows users to search through
// filtered charging stations, apply filters, and view the results sorted by proximity
// or availability.
//
// __version__ = "2.0.0"
//
// __author__ = "Christopher Schilling"

import 'package:flutter/material.dart';
import 'package:charging_station/models/api.dart';
import 'package:geolocator/geolocator.dart';
import 'package:charging_station/utils/helper.dart';
import 'package:easy_localization/easy_localization.dart';

/// A StatefulWidget that creates an overlay for searching charging stations.
///
/// This widget allows users to search and filter through charging stations
/// based on their address, availability, and other filter options such as
/// charging speed, plug type, and parking sensor availability.
///
/// [filteredStations] - The list of filtered charging stations to search through.
/// [searchController] - The controller for the search text field.
/// [currentPosition] - The current GPS position of the user for proximity-based sorting.
/// [onClose] - The callback that is called when the overlay is closed.
/// [onStationSelected] - The callback that is triggered when a station is selected.
/// [onFilterTap] - An optional callback that triggers when the filter button is pressed.
/// [selectedSpeed] - The selected charging speed filter.
/// [selectedPlugs] - The selected plug types filter.
/// [hasParkingSensor] - Whether or not the parking sensor filter is applied.
class SearchOverlay extends StatefulWidget {
  final List<ChargingStationInfo> filteredStations;
  final TextEditingController searchController;
  final Position? currentPosition;
  final VoidCallback onClose;
  final void Function(ChargingStationInfo station) onStationSelected;
  final VoidCallback? onFilterTap;
  final String selectedSpeed;
  final Set<String> selectedPlugs;
  final bool hasParkingSensor;

  const SearchOverlay({
    super.key,
    required this.filteredStations,
    required this.searchController,
    required this.currentPosition,
    required this.onClose,
    required this.onStationSelected,
    this.onFilterTap,
    required this.selectedSpeed,
    required this.selectedPlugs,
    required this.hasParkingSensor,
  });

  @override
  State<SearchOverlay> createState() => SearchOverlayState();
}

class SearchOverlayState extends State<SearchOverlay> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<ChargingStationInfo> displayStations = widget.filteredStations
        .where((ChargingStationInfo station) => station.address
            .toLowerCase()
            .contains(widget.searchController.text.toLowerCase()))
        .toList();

    if (widget.currentPosition != null) {
      displayStations.sort((ChargingStationInfo a, ChargingStationInfo b) {
        final int aAvailable = _countAvailableEvse(a);
        final int bAvailable = _countAvailableEvse(b);

        if (aAvailable == 0 && bAvailable > 0) return 1;
        if (aAvailable > 0 && bAvailable == 0) return -1;

        final double aDist =
            calculateDistance(widget.currentPosition!, a.coordinates);
        final double bDist =
            calculateDistance(widget.currentPosition!, b.coordinates);
        return aDist.compareTo(bDist);
      });
    } else {
      displayStations.sort((ChargingStationInfo a, ChargingStationInfo b) {
        final int aAvailable = _countAvailableEvse(a);
        final int bAvailable = _countAvailableEvse(b);

        if (aAvailable == 0 && bAvailable > 0) return 1;
        if (aAvailable > 0 && bAvailable == 0) return -1;

        return a.address.compareTo(b.address);
      });
    }

    return Positioned.fill(
      child: Container(
        padding: const EdgeInsets.all(20.0),
        color: const Color(0xFF282828),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _buildSearchContent(displayStations),
            const SizedBox(height: 16.0),
          ],
        ),
      ),
    );
  }

  int _countFilteredEvse(ChargingStationInfo station) {
    final Set<String> mappedPlugs =
        widget.selectedPlugs.map((String p) => plugTypeMap[p] ?? p).toSet();

    return station.evses.values.where((EvseInfo evse) {
      final bool plugMatches =
          mappedPlugs.isEmpty || mappedPlugs.contains(evse.chargingPlug);

      final bool speedMatches = widget.selectedSpeed == 'all' ||
          (widget.selectedSpeed == 'upto_50' && evse.maxPower <= 50) ||
          (widget.selectedSpeed == 'from_50' && evse.maxPower >= 50) ||
          (widget.selectedSpeed == 'from_100' && evse.maxPower >= 100) ||
          (widget.selectedSpeed == 'from_200' && evse.maxPower >= 200) ||
          (widget.selectedSpeed == 'from_300' && evse.maxPower >= 300);

      bool sensorMatches = true;
      if (widget.hasParkingSensor) {
        sensorMatches = evse.hasParkingSensor == true &&
            evse.parkingSensor?.sensorIssue != true;
      }

      return plugMatches && speedMatches && sensorMatches;
    }).length;
  }

  int _countAvailableEvse(ChargingStationInfo station) {
    final Set<String> mappedPlugs =
        widget.selectedPlugs.map((String p) => plugTypeMap[p] ?? p).toSet();

    return station.evses.values.where((EvseInfo evse) {
      final bool plugMatches =
          mappedPlugs.isEmpty || mappedPlugs.contains(evse.chargingPlug);

      final bool speedMatches = widget.selectedSpeed == 'all' ||
          (widget.selectedSpeed == 'upto_50' && evse.maxPower <= 50) ||
          (widget.selectedSpeed == 'from_50' && evse.maxPower >= 50) ||
          (widget.selectedSpeed == 'from_100' && evse.maxPower >= 100) ||
          (widget.selectedSpeed == 'from_200' && evse.maxPower >= 200) ||
          (widget.selectedSpeed == 'from_300' && evse.maxPower >= 300);

      bool sensorMatches = true;
      if (widget.hasParkingSensor) {
        sensorMatches = evse.hasParkingSensor == true &&
            evse.parkingSensor?.sensorIssue != true;
      }

      bool isAvailable;
      if (evse.hasParkingSensor == true && evse.parkingSensor != null) {
        if (evse.parkingSensor!.sensorIssue == true) {
          isAvailable = evse.status == 'AVAILABLE';
        } else {
          isAvailable =
              evse.status == 'AVAILABLE' && evse.illegallyParked == false;
        }
      } else {
        isAvailable = evse.status == 'AVAILABLE';
      }

      return plugMatches && speedMatches && sensorMatches && isAvailable;
    }).length;
  }

  Widget _buildSearchContent(List<ChargingStationInfo> displayStations) {
    return Container(
      height: 700.0,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            height: 60.0,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: Colors.black, width: 2.0),
            ),
            child: Row(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(left: 4.0, right: 8.0),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[200],
                    child: IconButton(
                      icon:
                          const Icon(Icons.filter_list, color: Colors.black87),
                      onPressed: widget.onFilterTap,
                      tooltip: 'filter'.tr(),
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: widget.searchController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'search'.tr(),
                      contentPadding:
                          const EdgeInsets.fromLTRB(8.0, 16.0, 8.0, 15.0),
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'close'.tr(),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16.0),
          Expanded(
            child: ListView.builder(
              itemCount: displayStations.length,
              itemBuilder: (BuildContext context, int index) {
                final ChargingStationInfo station = displayStations[index];
                final int availableCount = _countAvailableEvse(station);
                final int totalFilteredCount = _countFilteredEvse(station);

                String subtitleText = '';
                if (widget.currentPosition != null) {
                  final double distance = calculateDistance(
                    widget.currentPosition!,
                    station.coordinates,
                  );
                  subtitleText = '${formatDistance(distance)} ${'away'.tr()}, ';
                }

                subtitleText +=
                    '$availableCount/$totalFilteredCount ${'available'.tr()}';

                return Column(
                  children: <Widget>[
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
                      onTap: () {
                        widget.onStationSelected(station);
                        widget.onClose();
                      },
                    ),
                    const SizedBox(height: 16.0),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
