import 'package:flutter/material.dart';

import '../services/credentials_store.dart';
import '../services/pairing_service.dart';
import '../services/xtream_api_client.dart';
import 'home_screen.dart';

/// Shown on a device without stored credentials (typically a TV) so it can
/// receive them from another device that's already signed in, instead of
/// having the full host/username/password typed in via a remote control.
class PairReceiveScreen extends StatefulWidget {
  const PairReceiveScreen({super.key});

  @override
  State<PairReceiveScreen> createState() => _PairReceiveScreenState();
}

class _PairReceiveScreenState extends State<PairReceiveScreen> {
  late String _code;
  PairingReceiver? _receiver;
  String? _error;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    setState(() {
      _code = generatePairingCode();
      _error = null;
      _connecting = false;
    });

    final receiver = PairingReceiver();
    _receiver = receiver;
    receiver.listen(_code).then((credentials) async {
      if (!mounted) return;
      setState(() => _connecting = true);

      final client = XtreamApiClient(credentials);
      try {
        await client.authenticate();
        await CredentialsStore().save(credentials);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomeScreen(client: client)),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _connecting = false;
          _error = 'Received credentials didn\'t work: $e';
        });
      }
    }).catchError((Object e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    });
  }

  @override
  void dispose() {
    _receiver?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Pair with another device')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cast_connected, size: 56, color: colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'On a device that\'s already signed in, open Account and choose '
                  '"Add a device", then enter this code:',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    _code.replaceAllMapped(
                      RegExp(r'.{1,4}'),
                      (m) => '${m.group(0)} ',
                    ).trim(),
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                if (_error != null) ...[
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colorScheme.error),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _startListening,
                    child: const Text('Get a new code'),
                  ),
                ] else ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _connecting ? 'Signing in...' : 'Waiting for a device...',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
