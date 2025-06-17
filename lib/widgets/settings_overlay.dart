// Created 14.03.2024 by Christopher Schilling
//
// This file creates a settings overlay that allows users to configure language preferences and contact/legal information.
//
// __version__ = "2.0.0"
//
// __author__ = "Christopher Schilling"

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A StatefulWidget that creates a settings overlay.
///
/// This widget allows users to modify settings like language, theme, and access legal/contact information.
/// It supports language change and displays options for modifying settings.
///
/// [onClose] - A callback function that will be triggered when the overlay is closed.
class SettingsOverlay extends StatefulWidget {
  final VoidCallback onClose;

  const SettingsOverlay({
    super.key,
    required this.onClose,
  });

  @override
  SettingsOverlayState createState() => SettingsOverlayState();
}

/// State for the SettingsOverlay widget.
///
/// This class manages the state of the SettingsOverlay widget, including saving the selected locale
/// and handling UI interactions like changing language and viewing contact/legal information.
class SettingsOverlayState extends State<SettingsOverlay> {
  late Locale _selectedLocale;

  final Map<String, Locale> languageMap = <String, Locale>{
    'Deutsch': const Locale('de'),
    'English': const Locale('en'),
    'Français': const Locale('fr'),
    'Español': const Locale('es'),
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectedLocale = context.locale;
  }

  /// Saves the selected locale to SharedPreferences for persistent storage.
  ///
  /// [locale] - The selected locale that will be saved.
  Future<void> _saveLocale(Locale locale) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedLocale', locale.languageCode);
  }

  /// Displays a contact dialog with email and phone information.
  ///
  /// [context] - The BuildContext used to show the dialog.
  void _showContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF282828),
          title: Text(
            'Kontakt'.tr(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFFB2BEB5),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${'email'.tr()}: TestMail',
                style: const TextStyle(
                  color: Color(0xFFB2BEB5),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${'phone'.tr()}: TestNr',
                style: const TextStyle(
                  color: Color(0xFFB2BEB5),
                  fontSize: 16,
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'close'.tr(),
                style: const TextStyle(
                  color: Color(0xFFB2BEB5),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      child: Material(
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
                      'settings'.tr(),
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

                // Language Settings
                Text(
                  'language'.tr(),
                  style: const TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB2BEB5),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB2BEB5),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Locale>(
                      dropdownColor: const Color(0xFFB2BEB5),
                      value: _selectedLocale,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down,
                          color: Color(0xFF282828)),
                      items: languageMap.entries
                          .map((MapEntry<String, Locale> entry) =>
                              DropdownMenuItem<Locale>(
                                value: entry.value,
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    color: Color(0xFF282828),
                                    fontSize: 17.0,
                                  ),
                                ),
                              ))
                          .toList(),
                      onChanged: (Locale? newLocale) async {
                        if (newLocale != null) {
                          setState(() {
                            _selectedLocale = newLocale;
                          });
                          context.setLocale(newLocale);
                          await _saveLocale(newLocale);
                        }
                      },
                      style: const TextStyle(
                        color: Color(0xFF282828),
                        fontSize: 18.0,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Contact / Legal Information
                Text(
                  'legal'.tr(),
                  style: const TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB2BEB5),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB2BEB5),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8.0),
                    onTap: () {
                      _showContactDialog(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Kontakt'.tr(),
                        style: const TextStyle(
                          color: Color(0xFF282828),
                          fontSize: 17,
                        ),
                        textAlign: TextAlign.left,
                      ),
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
