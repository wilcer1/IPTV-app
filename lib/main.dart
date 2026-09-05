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
  // Flutter's default image cache (1000 images / 100MB) assumes headroom
  // this app doesn't have on cheap Android TV hardware: a Chromecast HD
  // has ~1.4GB of RAM total, nearly all of it already claimed by ~35+
  // background processes the OS keeps warm (Play Services, Play Store,
  // launcher, Assistant, other installed apps, vendor services). There's
  // essentially no slack to absorb a burst decode, so keep our own
  // footprint small and predictable instead.
  PaintingBinding.instance.imageCache.maximumSize = 150;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 24 * 1024 * 1024;
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
