// Created 14.03.2024 by Christopher Schilling
//
// This file builds the FilterOverlay Widget, which allows users to filter charging stations
// based on charging speed, plug type, and parking sensor availability.
//
// __version__ = "2.0.0"
//
// __author__ = "Christopher Schilling"

import 'package:flutter/material.dart';
import 'package:charging_station/utils/helper.dart';
import 'package:easy_localization/easy_localization.dart';

/// A StatefulWidget that builds an overlay for applying filters to the charging stations.
///
/// The widget allows the user to select filters for:
/// - Charging speed (only one selection allowed).
/// - Plug type(s) (multiple selections allowed).
/// - Parking sensor availability (boolean option).
///
/// [onClose] - The callback function that is executed when the overlay is closed.
/// [onApply] - The callback function that is executed when the user applies the selected filters.
class FilterOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final Function(String selectedSpeed, Set<String> selectedPlugs,
      bool hasParkingSensor) onApply;

  const FilterOverlay({
    super.key,
    required this.onClose,
    required this.onApply,
  });

  @override
  State<FilterOverlay> createState() => _FilterOverlayState();
}

/// The state of the [FilterOverlay] widget.
///
/// It manages the filter selection state, including the selected speed, plugs, and parking sensor.
class _FilterOverlayState extends State<FilterOverlay> {
  final List<String> speedOptions = <String>[
    'all',
    'upto_50',
    'from_50',
    'from_100',
    'from_200',
    'from_300'
  ]; // List of available speed options
  String selectedSpeed = 'all'; // Default speed selection

  final List<String> plugOptions = <String>[
    'Typ2',
    'CCS',
    'CHAdeMO',
  ]; // List of available plug types
  Set<String> selectedPlugs = <String>{};

  bool hasParkingSensor = false;

  @override
  void initState() {
    super.initState();
    _loadSavedFilters();
  }

  /// Loads the previously saved filters for speed, plug types, and parking sensor.
  ///
  /// This function fetches the saved preferences using helper functions and updates the state accordingly.
  Future<void> _loadSavedFilters() async {
    final String speed = await loadSelectedSpeed();
    final Set<String> plugs = await loadSelectedPlugs();
    final bool sensor = await loadSelectedParkingSensor();
    setState(() {
      selectedSpeed = speed;
      selectedPlugs = plugs;
      hasParkingSensor = sensor;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF282828),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'filter'.tr(),
                    style: const TextStyle(
                      fontSize: 24.0,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB2BEB5),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Color(0xFFB2BEB5), size: 28),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(color: Color(0xFFB2BEB5)),
              const SizedBox(height: 10),

              Expanded(
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'speed'.tr(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB2BEB5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Column(
                          children: speedOptions.map((String optionKey) {
                            return CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.trailing,
                              activeColor: Colors.green,
                              value: selectedSpeed == optionKey,
                              onChanged: (_) {
                                setState(() {
                                  selectedSpeed = optionKey;
                                });
                              },
                              title: Text(
                                tr(optionKey),
                                style: const TextStyle(
                                    color: Color(0xFFB2BEB5), fontSize: 18),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'plug'.tr(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB2BEB5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Column(
                          children: plugOptions.map((String plug) {
                            return CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.trailing,
                              activeColor: Colors.green,
                              value: selectedPlugs.contains(plug),
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    selectedPlugs.add(plug);
                                  } else {
                                    selectedPlugs.remove(plug);
                                  }
                                });
                              },
                              title: Text(
                                plug,
                                style: const TextStyle(
                                    color: Color(0xFFB2BEB5), fontSize: 18),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'parking_sensor'.tr(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB2BEB5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.trailing,
                          activeColor: Colors.green,
                          value: hasParkingSensor,
                          onChanged: (bool? value) {
                            setState(() {
                              hasParkingSensor = value ?? false;
                            });
                          },
                          title: Text(
                            'filter_parking_sensor'.tr(),
                            style: const TextStyle(
                                color: Color(0xFFB2BEB5), fontSize: 18),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),

              // Apply Filter button
              ElevatedButton(
                onPressed: () async {
                  await saveSelectedSpeed(selectedSpeed);
                  await saveSelectedPlugs(selectedPlugs);
                  await saveSelectedParkingSensor(hasParkingSensor);
                  widget.onApply(
                      selectedSpeed, selectedPlugs, hasParkingSensor);
                  widget.onClose();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: Text(
                  'apply_filter'.tr(),
                  style:
                      const TextStyle(color: Color(0xFFB2BEB5), fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
