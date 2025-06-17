// Created 14.03.2024 by Christopher Schilling
//
// This file builds a widget to display detailed information about a charging station,
// including the address, available chargers, EVSE details, and the option to toggle favorites.
//
// __version__ = "2.0.0"
//
// __author__ = "Christopher Schilling"

import 'package:flutter/material.dart';
import 'package:charging_station/models/api.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:charging_station/utils/helper.dart';
import 'package:easy_localization/easy_localization.dart';

/// A widget to display the details of a selected charging station.
///
/// This widget provides information about the station's address, available chargers,
/// EVSE details, and provides the option to add the station to favorites. It also
/// allows users to get directions to the station using Google Maps.
///
/// [selectedStation] - The charging station whose details are displayed.
/// [isFavorite] - A flag indicating whether the station is a favorite or not.
/// [toggleFavorite] - A function that toggles the station's favorite status.
/// [onDismiss] - A callback function to dismiss the widget when swiped down.
/// [currentPosition] - The current location of the user (if available) to calculate distance.
class StationDetailsWidget extends StatelessWidget {
  final ChargingStationInfo selectedStation;
  final bool isFavorite;
  final Function(String) toggleFavorite;
  final Function() onDismiss;
  final Position? currentPosition;

  const StationDetailsWidget({
    required this.selectedStation,
    required this.isFavorite,
    required this.toggleFavorite,
    required this.onDismiss,
    this.currentPosition,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (DragUpdateDetails details) {
        if (details.delta.dy > 0) {
          onDismiss();
        }
      },
      child: Dismissible(
        key: const ValueKey('dismissible'),
        direction: DismissDirection.down,
        onDismissed: (_) => onDismiss(),
        child: Container(
          height: 350,
          decoration: BoxDecoration(
            color: const Color(0xFF282828),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(40.0),
              topRight: Radius.circular(40.0),
            ),
            border: Border.all(
              color: const Color(0xFF282828),
              width: 2.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Column(
                    children: <Widget>[
                      Text(
                        selectedStation.address,
                        style: const TextStyle(
                          fontSize: 22.0,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB2BEB5),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          ElevatedButton(
                            onPressed: () {
                              launchUrl(Uri.parse(
                                'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(selectedStation.address)}',
                              ));
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 8.0),
                            ),
                            child: Text(
                              'route'.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10.0),
                          Builder(
                            builder: (BuildContext context) {
                              final int availableCount = selectedStation
                                  .evses.values
                                  .where((EvseInfo evse) =>
                                      evse.status == 'AVAILABLE' &&
                                      (!evse.hasParkingSensor ||
                                          evse.parkingSensor == null ||
                                          evse.parkingSensor!.sensorIssue ==
                                              true ||
                                          (evse.parkingSensor!.sensorIssue ==
                                                  false &&
                                              evse.illegallyParked == false)))
                                  .length;

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0, vertical: 8.0),
                                decoration: BoxDecoration(
                                  color: availableCount > 0
                                      ? Colors.green
                                      : Colors.red,
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                child: Text(
                                  availableCount == 0
                                      ? '0 ${'chargers_available'.tr()}'
                                      : availableCount == 1
                                          ? '1 ${'charger_available'.tr()}'
                                          : '$availableCount ${'chargers_available'.tr()}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15.0,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 10.0),
                          ElevatedButton(
                            onPressed: () {
                              toggleFavorite(selectedStation.id.toString());
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isFavorite ? Colors.green : Colors.grey,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 8.0),
                            ),
                            child: Text(
                              isFavorite
                                  ? 'favorite'.tr()
                                  : 'add_favorite'.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10.0),
                if (currentPosition != null)
                  Center(
                    child: Text(
                      '${'distance'.tr()}: ${formatDistance(calculateDistance(currentPosition!, selectedStation.coordinates))}',
                      style: const TextStyle(
                        fontSize: 20.0,
                        color: Color(0xFFB2BEB5),
                      ),
                    ),
                  ),
                const SizedBox(height: 10.0),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: <Widget>[
                        for (EvseInfo evse
                            in selectedStation.evses.values.toList()
                              ..sort((EvseInfo a, EvseInfo b) =>
                                  a.status.compareTo(b.status)))
                          Column(
                            children: <Widget>[
                              const Divider(
                                color: Color(0xFFB2BEB5),
                                thickness: 1.0,
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: <Widget>[
                                  Icon(
                                    Icons.circle,
                                    color: (evse.status == 'AVAILABLE' &&
                                            (!evse.hasParkingSensor ||
                                                evse.parkingSensor == null ||
                                                evse.parkingSensor!
                                                        .sensorIssue ==
                                                    true ||
                                                (evse.parkingSensor!
                                                            .sensorIssue ==
                                                        false &&
                                                    evse.illegallyParked ==
                                                        false)))
                                        ? Colors.green
                                        : Colors.red,
                                    size: 24.0,
                                  ),
                                  const SizedBox(width: 8.0),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        (evse.status == 'AVAILABLE' &&
                                                (!evse.hasParkingSensor ||
                                                    evse.parkingSensor ==
                                                        null ||
                                                    evse.parkingSensor!
                                                            .sensorIssue ==
                                                        true ||
                                                    (evse.parkingSensor!
                                                                .sensorIssue ==
                                                            false &&
                                                        evse.illegallyParked ==
                                                            false)))
                                            ? 'available'.tr()
                                            : ((evse.status == 'AVAILABLE' &&
                                                    evse.hasParkingSensor &&
                                                    evse.parkingSensor !=
                                                        null &&
                                                    evse.parkingSensor!
                                                            .sensorIssue ==
                                                        false &&
                                                    evse.illegallyParked ==
                                                        true)
                                                ? 'occupied'.tr()
                                                : 'occupied'.tr()),
                                        style: const TextStyle(
                                          fontSize: 20.0,
                                          color: Color(0xFFB2BEB5),
                                        ),
                                      ),
                                      Text(
                                        '${evse.maxPower} kW',
                                        style: const TextStyle(
                                          fontSize: 20.0,
                                          color: Color(0xFFB2BEB5),
                                        ),
                                      ),
                                      if (evse.hasParkingSensor &&
                                          evse.parkingSensor != null)
                                        Text(
                                          'parking_sensor_build'.tr(),
                                          style: const TextStyle(
                                            fontSize: 18.0,
                                            color: Colors.lightBlue,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Padding(
                                    padding: const EdgeInsets.only(right: 20.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              right: 10.0),
                                          child: (() {
                                            switch (evse.chargingPlug) {
                                              case 'IEC_62196_T2':
                                                return Image.asset(
                                                  'assets/images/typ2.png',
                                                  width: 50,
                                                  height: 50,
                                                );
                                              case 'IEC_62196_T2_COMBO':
                                                return Image.asset(
                                                  'assets/images/ccs.png',
                                                  width: 50,
                                                  height: 50,
                                                );
                                              case 'CHADEMO':
                                                return Image.asset(
                                                  'assets/images/chademo.png',
                                                  width: 50,
                                                  height: 50,
                                                );
                                              default:
                                                return Icon(
                                                  getPlugIcon(
                                                      evse.chargingPlug),
                                                  size: 50.0,
                                                  color:
                                                      const Color(0xFFB2BEB5),
                                                );
                                            }
                                          })(),
                                        ),
                                        Text(
                                          formatPlugType(evse.chargingPlug),
                                          style: const TextStyle(
                                            fontSize: 18.0,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFFB2BEB5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
