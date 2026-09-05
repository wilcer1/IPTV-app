import 'package:flutter/material.dart';

import '../services/credentials_store.dart';
import '../services/favorites_store.dart';
import '../services/theme_controller.dart';
import '../services/xtream_api_client.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    final credentialsFuture = CredentialsStore().load();
    final favoritesFuture = FavoritesStore.instance.ensureLoaded();
    final themeFuture = ThemeController.instance.ensureLoaded();
    final credentials = await credentialsFuture;
    await favoritesFuture;
    await themeFuture;
    if (!mounted) return;

    if (credentials == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    final client = XtreamApiClient(credentials);
    try {
      await client.authenticate();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(client: client)),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.live_tv_rounded, size: 72, color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'IPTV',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
