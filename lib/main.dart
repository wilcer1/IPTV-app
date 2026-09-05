import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'screens/splash_screen.dart';
import 'services/device_info.dart';
import 'services/theme_controller.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await DeviceInfo.isTv();
  runApp(const IptvApp());
}

class IptvApp extends StatelessWidget {
  const IptvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'IPTV',
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode: ThemeController.instance.mode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
