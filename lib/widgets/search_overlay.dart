import 'package:flutter/material.dart';
import 'package:charging_station/models/api.dart';
import 'package:geolocator/geolocator.dart';
import 'package:charging_station/utils/helper.dart';
import 'package:easy_localization/easy_localization.dart';

class SearchOverlay extends StatefulWidget {
  final List<ChargingStationInfo> filteredStations;
  final TextEditingController searchController;
  final Position? currentPosition;
  final VoidCallback onClose;
  final void Function(ChargingStationInfo station) onStationSelected;
  final VoidCallback? onFilterTap;

  // Neu: Filterparameter übergeben!
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
  SearchOverlayState createState() => SearchOverlayState();
}

class SearchOverlayState extends State<SearchOverlay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  @override
  Widget build(BuildContext context) {
    List<ChargingStationInfo> displayStations = widget.filteredStations
        .where((station) => station.address
            .toLowerCase()
            .contains(widget.searchController.text.toLowerCase()))
        .toList();

    if (widget.currentPosition != null) {
      displayStations.sort((a, b) {
        final aAvailable = _countAvailableEvse(a);
        final bAvailable = _countAvailableEvse(b);

        if (aAvailable == 0 && bAvailable > 0) return 1;
        if (aAvailable > 0 && bAvailable == 0) return -1;

        final aDist = calculateDistance(widget.currentPosition!, a.coordinates);
        final bDist = calculateDistance(widget.currentPosition!, b.coordinates);
        return aDist.compareTo(bDist);
      });
    } else {
      displayStations.sort((a, b) {
        final aAvailable = _countAvailableEvse(a);
        final bAvailable = _countAvailableEvse(b);

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
          children: [
            _buildSearchContent(displayStations),
            const SizedBox(height: 16.0),
          ],
        ),
      ),
    );
  }

  /// Gibt die Zahl der insgesamt passenden Ladepunkte zurück (Filter!)
  int _countFilteredEvse(ChargingStationInfo station) {
    final mappedPlugs =
        widget.selectedPlugs.map((p) => plugTypeMap[p] ?? p).toSet();

    return station.evses.values.where((evse) {
      final plugMatches =
          mappedPlugs.isEmpty || mappedPlugs.contains(evse.chargingPlug);

      final speedMatches = widget.selectedSpeed == 'all' ||
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

  /// Gibt die Zahl der freien Ladepunkte zurück (mit Filter & verfügbar)
  int _countAvailableEvse(ChargingStationInfo station) {
    final mappedPlugs =
        widget.selectedPlugs.map((p) => plugTypeMap[p] ?? p).toSet();

    return station.evses.values.where((evse) {
      final plugMatches =
          mappedPlugs.isEmpty || mappedPlugs.contains(evse.chargingPlug);

      final speedMatches = widget.selectedSpeed == 'all' ||
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
        children: [
          // Suchfeld mit Filter-Button und Close
          Container(
            height: 60.0,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: Colors.black, width: 2.0),
            ),
            child: Row(
              children: [
                // Filter-Button
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
                // Suchfeld
                Expanded(
                  child: TextField(
                    controller: widget.searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'search'.tr(),
                      contentPadding:
                          const EdgeInsets.fromLTRB(8.0, 16.0, 8.0, 15.0),
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                ),
                // Close-Button
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'close'.tr(),
                  onPressed: () {
                    setState(() {
                      widget.onClose();
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16.0),
          Expanded(
            child: ListView.builder(
              itemCount: displayStations.length,
              itemBuilder: (context, index) {
                ChargingStationInfo station = displayStations[index];
                int availableCount = _countAvailableEvse(station);
                int totalFilteredCount = _countFilteredEvse(station);

                String subtitleText = '';
                if (widget.currentPosition != null) {
                  double distance = calculateDistance(
                      widget.currentPosition!, station.coordinates);
                  subtitleText = '${formatDistance(distance)} ${'away'.tr()}, ';
                }

                subtitleText +=
                    '$availableCount/$totalFilteredCount ${'available'.tr()}';

                return Column(
                  children: [
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
                        setState(() {
                          widget.onStationSelected(station);
                          widget.onClose();
                        });
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
