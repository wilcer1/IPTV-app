import 'package:flutter/material.dart';

import '../models/xtream_credentials.dart';
import '../services/credentials_store.dart';
import '../services/xtream_api_client.dart';
import '../widgets/tv_text_field.dart';
import 'home_screen.dart';
import 'pair_receive_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _hostController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _hostFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _credentialsStore = CredentialsStore();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _credentialsStore.load().then((creds) {
      if (creds == null || !mounted) return;
      setState(() {
        _hostController.text = creds.host;
        _usernameController.text = creds.username;
        _passwordController.text = creds.password;
      });
    });
  }

  @override
  void dispose() {
    _hostController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _hostFocus.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  String _normalizeHost(String raw) {
    var host = raw.trim();
    if (!host.startsWith('http://') && !host.startsWith('https://')) {
      host = 'http://$host';
    }
    while (host.endsWith('/')) {
      host = host.substring(0, host.length - 1);
    }
    return host;
  }

  Future<void> _connect() async {
    // On Android TV, the D-pad only navigates within the on-screen keyboard
    // while a field is focused — unfocusing here is what actually dismisses
    // it and hands control back to the remote.
    FocusScope.of(context).unfocus();

    final credentials = XtreamCredentials(
      host: _normalizeHost(_hostController.text),
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (credentials.host.isEmpty ||
        credentials.username.isEmpty ||
        credentials.password.isEmpty) {
      setState(() => _error = 'Host, username, and password are all required.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final client = XtreamApiClient(credentials);
    try {
      await client.authenticate();
      await _credentialsStore.save(credentials);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => HomeScreen(client: client)),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.live_tv_rounded, size: 64, color: colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    'Welcome back',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sign in with your Xtream Codes account',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 28),
                  TvTextField(
                    controller: _hostController,
                    focusNode: _hostFocus,
                    keyboardTitle: 'Host',
                    decoration: const InputDecoration(
                      labelText: 'Host',
                      hintText: 'http://example.com:8080',
                      prefixIcon: Icon(Icons.dns_outlined),
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _usernameFocus.requestFocus(),
                  ),
                  const SizedBox(height: 12),
                  TvTextField(
                    controller: _usernameController,
                    focusNode: _usernameFocus,
                    keyboardTitle: 'Username',
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                  ),
                  const SizedBox(height: 12),
                  TvTextField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    keyboardTitle: 'Password',
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _connect(),
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
                    onPressed: _loading ? null : _connect,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Connect'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PairReceiveScreen(),
                              ),
                            ),
                    child: const Text('Sign in by pairing with another device'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
