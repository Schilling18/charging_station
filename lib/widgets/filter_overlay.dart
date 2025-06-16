import 'package:flutter/material.dart';
import 'package:charging_station/utils/helper.dart';
import 'package:easy_localization/easy_localization.dart';

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

class _FilterOverlayState extends State<FilterOverlay> {
  final List<String> speedOptions = [
    'all',
    'upto_50',
    'from_50',
    'from_100',
    'from_200',
    'from_300'
  ];
  String selectedSpeed = 'all';

  final List<String> plugOptions = [
    'Typ2',
    'CCS',
    'CHAdeMO',
  ];
  Set<String> selectedPlugs = {};

  bool hasParkingSensor = false;

  @override
  void initState() {
    super.initState();
    _loadSavedFilters();
  }

  Future<void> _loadSavedFilters() async {
    final speed = await loadSelectedSpeed();
    final plugs = await loadSelectedPlugs();
    final sensor = await loadSelectedParkingSensor();
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
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "filter".tr(),
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
                      children: [
                        // Ladegeschwindigkeit (nur eine Auswahl)
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
                          children: speedOptions.map((optionKey) {
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

                        // Steckertypen (mehrere möglich)
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
                          children: plugOptions.map((plug) {
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
