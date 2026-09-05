import 'package:flutter/material.dart';

import '../models/xtream_credentials.dart';
import '../services/pairing_service.dart';
import '../widgets/tv_text_field.dart';

/// Shown on a device that's already signed in, to hand its Xtream
/// credentials to a fresh device (typically a TV) over the local network.
class PairSendScreen extends StatefulWidget {
  final XtreamCredentials credentials;

  const PairSendScreen({super.key, required this.credentials});

  @override
  State<PairSendScreen> createState() => _PairSendScreenState();
}

class _PairSendScreenState extends State<PairSendScreen> {
  final _codeController = TextEditingController();
  bool _sending = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final code = _codeController.text;
    if (code.trim().isEmpty) {
      setState(() => _error = 'Enter the code shown on the other device.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await PairingSender().send(code, widget.credentials);
      if (!mounted) return;
      setState(() => _success = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Add a device')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tv_outlined, size: 56, color: colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Open this app on the new device (e.g. your TV) and enter '
                  'the code it shows here. Both devices need to be on the '
                  'same Wi-Fi network.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 28),
                if (_success) ...[
                  Icon(Icons.check_circle, size: 48, color: colorScheme.primary),
                  const SizedBox(height: 12),
                  const Text('Signed in on the other device.'),
                ] else ...[
                  TvTextField(
                    controller: _codeController,
                    keyboardTitle: 'Enter code',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28, letterSpacing: 4, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(hintText: 'CODE'),
                    onSubmitted: (_) => _sending ? null : _send(),
                  ),
                  const SizedBox(height: 20),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ),
                  FilledButton(
                    onPressed: _sending ? null : _send,
                    child: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send credentials'),
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
