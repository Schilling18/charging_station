// Created 14.03.2024 by Christopher Schilling
//
// This file builds the BottomBar Widget.
//
// __version__ = "2.0.0"
//
// __author__ = "Christopher Schilling"

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// A widget that builds the BottomBar, typically displayed at the bottom of the screen.
///
/// The BottomBar contains three buttons (Favorites, Settings, Filter) that can be tapped to trigger corresponding actions.
///
/// [onFavoritesTap] - The callback function when the "Favorites" button is tapped.
/// [onSettingsTap] - The callback function when the "Settings" button is tapped.
/// [onFilterTap] - The callback function when the "Filter" button is tapped.
class BottomBar extends StatelessWidget {
  final VoidCallback onFavoritesTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onFilterTap;

  /// Constructor for the BottomBar widget.
  ///
  /// [onFavoritesTap] - The function to be called when the "Favorites" button is tapped.
  /// [onSettingsTap] - The function to be called when the "Settings" button is tapped.
  /// [onFilterTap] - The function to be called when the "Filter" button is tapped.
  const BottomBar({
    super.key,
    required this.onFavoritesTap,
    required this.onSettingsTap,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      height: 70,
      color: const Color(0xFF282828),
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      child: SizedBox(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildBottomButton(
              label: tr('favorites'),
              onPressed: onFavoritesTap,
            ),
            _buildBottomButton(
              label: tr('settings'),
              onPressed: onSettingsTap,
            ),
            _buildBottomButton(
              label: tr('filter'),
              onPressed: onFilterTap,
            ),
          ],
        ),
      ),
    );
  }

  /// Helper method to build a button for the BottomBar.
  ///
  /// [label] - The text label for the button.
  /// [onPressed] - The callback function that will be executed when the button is pressed.
  ///
  /// Returns an ElevatedButton widget with the provided label and onPressed callback.
  Widget _buildBottomButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 16.0,
          color: Colors.black,
        ),
      ),
    );
  }
}
