import 'package:flutter/material.dart';

import 'localization/app_strings.dart';
import 'screens/radar_screen.dart';
import 'services/app_preferences_controller.dart';
import 'theme/app_theme.dart';

class CryptoRadarApp extends StatefulWidget {
  const CryptoRadarApp({super.key, this.autoStart = true});

  final bool autoStart;

  @override
  State<CryptoRadarApp> createState() => _CryptoRadarAppState();
}

class _CryptoRadarAppState extends State<CryptoRadarApp> {
  late final AppPreferencesController _preferences;

  @override
  void initState() {
    super.initState();
    _preferences = AppPreferencesController();
  }

  @override
  void dispose() {
    _preferences.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _preferences,
      builder: (BuildContext context, Widget? child) {
        return AppLocalization(
          strings: AppStrings(_preferences.language),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Crypto Radar',
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: _preferences.themeMode,
            home: CryptoRadarHome(
              autoStart: widget.autoStart,
              preferences: _preferences,
            ),
          ),
        );
      },
    );
  }
}
