// Created 14.03.2024 by Christopher Schilling
//
// This file sets up the application with localization, environment variables, and
// runs the MapScreen as the home screen of the app.
//
// __version__ = "2.0.0"
//
// __author__ = "Christopher Schilling"

import 'package:charging_station/screen/map_screen.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// The entry point of the application.
/// This function ensures that the necessary initialization tasks are completed
/// before the app starts, including loading environment variables and localization.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await dotenv.load();

  runApp(
    EasyLocalization(
      supportedLocales: const <Locale>[
        Locale('en'), // English locale
        Locale('fr'), // French locale
        Locale('de'), // German locale
        Locale('es') // Spanish locale
      ],
      path: 'assets/langs',
      fallbackLocale: const Locale('de'), // Default locale if no match found
      child: const MyApp(),
    ),
  );
}

/// The root widget of the application that initializes the MaterialApp.
/// It sets the locale, localizations, and home screen of the app.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'app_title'.tr(),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: const MapScreen(),
    );
  }
}
