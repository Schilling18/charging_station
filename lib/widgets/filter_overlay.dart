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
                        Text(
                          'speed'.tr(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB2BEB5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // ChoiceChips für Ladegeschwindigkeit
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: speedOptions.map((optionKey) {
                            final isSelected = selectedSpeed == optionKey;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: ChoiceChip(
                                label: Text(tr(optionKey)),
                                selected: isSelected,
                                selectedColor: Colors.green,
                                backgroundColor: const Color(0xFFB2BEB5),
                                labelStyle: TextStyle(
                                  color:
                                      isSelected ? Colors.white : Colors.black,
                                ),
                                onSelected: (_) {
                                  setState(() {
                                    selectedSpeed = optionKey;
                                  });
                                },
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
                        // FilterChips für Steckertypen
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: plugOptions.map((plug) {
                            final isSelected = selectedPlugs.contains(plug);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: FilterChip(
                                label: Text(plug),
                                selected: isSelected,
                                selectedColor: Colors.green,
                                backgroundColor: const Color(0xFFB2BEB5),
                                labelStyle: TextStyle(
                                  color:
                                      isSelected ? Colors.white : Colors.black,
                                ),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      selectedPlugs.add(plug);
                                    } else {
                                      selectedPlugs.remove(plug);
                                    }
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                        // Parksensor Filter
                        Row(
                          children: [
                            Switch(
                              value: hasParkingSensor,
                              activeColor: Colors.green,
                              onChanged: (value) {
                                setState(() {
                                  hasParkingSensor = value;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "filter_parking_sensor".tr(),
                              style: const TextStyle(
                                fontSize: 18,
                                color: Color(0xFFB2BEB5),
                              ),
                            ),
                          ],
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
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
