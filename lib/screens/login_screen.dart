import 'package:flutter/material.dart';

import '../models/xtream_credentials.dart';
import '../services/credentials_store.dart';
import '../services/xtream_api_client.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _hostController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
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
    return Scaffold(
      appBar: AppBar(title: const Text('IPTV')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Sign in with your Xtream Codes account'),
                const SizedBox(height: 16),
                TextField(
                  controller: _hostController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Host',
                    hintText: 'http://example.com:8080',
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Username',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Password',
                  ),
                  obscureText: true,
                  onSubmitted: (_) => _connect(),
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
