import 'package:flutter/material.dart';

import '../models/login_config.dart';
import '../models/xtream_credentials.dart';
import '../services/credentials_store.dart';
import '../services/iptv_client.dart';
import '../services/m3u_client.dart';
import '../services/xtream_api_client.dart';
import '../widgets/tv_text_field.dart';
import 'home_screen.dart';
import 'pair_receive_screen.dart';

enum _LoginMode { xtream, m3u }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _hostController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _m3uUrlController = TextEditingController();
  final _epgUrlController = TextEditingController();
  final _hostFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _m3uUrlFocus = FocusNode();
  final _epgUrlFocus = FocusNode();
  final _credentialsStore = CredentialsStore();
  _LoginMode _mode = _LoginMode.xtream;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _credentialsStore.load().then((login) {
      if (login == null || !mounted) return;
      setState(() {
        switch (login) {
          case XtreamLogin(:final credentials):
            _mode = _LoginMode.xtream;
            _hostController.text = credentials.host;
            _usernameController.text = credentials.username;
            _passwordController.text = credentials.password;
          case M3uLogin(:final url, :final epgUrl):
            _mode = _LoginMode.m3u;
            _m3uUrlController.text = url;
            _epgUrlController.text = epgUrl ?? '';
        }
      });
    });
  }

  @override
  void dispose() {
    _hostController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _m3uUrlController.dispose();
    _epgUrlController.dispose();
    _hostFocus.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _m3uUrlFocus.dispose();
    _epgUrlFocus.dispose();
    super.dispose();
  }

  String _normalizeUrl(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    return url;
  }

  String _normalizeHost(String raw) {
    var host = _normalizeUrl(raw);
    while (host.endsWith('/')) {
      host = host.substring(0, host.length - 1);
    }
    return host;
  }

  Future<(IptvClient, LoginConfig)> _signInXtream() async {
    final credentials = XtreamCredentials(
      host: _normalizeHost(_hostController.text),
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (credentials.host.isEmpty ||
        credentials.username.isEmpty ||
        credentials.password.isEmpty) {
      throw 'Host, username, and password are all required.';
    }

    final client = XtreamApiClient(credentials);
    await client.authenticate();
    return (client, XtreamLogin(credentials));
  }

  Future<(IptvClient, LoginConfig)> _signInM3u() async {
    final url = _normalizeUrl(_m3uUrlController.text);
    if (url.isEmpty) throw 'Enter your M3U playlist link.';

    // A "get.php?username=...&password=..." link is really an Xtream account
    // in disguise; prefer the full Xtream experience (categories, series
    // seasons, account info) and only fall back to plain M3U if the panel
    // doesn't answer its API.
    final xtream = XtreamCredentials.tryFromPlaylistUrl(url);
    if (xtream != null) {
      try {
        final client = XtreamApiClient(xtream);
        await client.authenticate();
        return (client, XtreamLogin(xtream));
      } catch (_) {
        // Fall through to treating it as a plain playlist.
      }
    }

    final epgUrl = _normalizeUrl(_epgUrlController.text);
    final login = M3uLogin(url: url, epgUrl: epgUrl.isEmpty ? null : epgUrl);
    final client = M3uClient(login);
    await client.authenticate();
    return (client, login);
  }

  Future<void> _connect() async {
    // On Android TV, the D-pad only navigates within the on-screen keyboard
    // while a field is focused — unfocusing here is what actually dismisses
    // it and hands control back to the remote.
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final (client, login) =
          await (_mode == _LoginMode.xtream ? _signInXtream() : _signInM3u());
      await _credentialsStore.save(login);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => HomeScreen(client: client)),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isXtream = _mode == _LoginMode.xtream;

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
                    isXtream
                        ? 'Sign in with your Xtream Codes account'
                        : 'Load your M3U playlist link',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  SegmentedButton<_LoginMode>(
                    segments: const [
                      ButtonSegment(value: _LoginMode.xtream, label: Text('Xtream')),
                      ButtonSegment(value: _LoginMode.m3u, label: Text('M3U link')),
                    ],
                    selected: {_mode},
                    onSelectionChanged: _loading
                        ? null
                        : (selection) => setState(() {
                              _mode = selection.first;
                              _error = null;
                            }),
                  ),
                  const SizedBox(height: 20),
                  if (isXtream) ...[
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
                  ] else ...[
                    TvTextField(
                      controller: _m3uUrlController,
                      focusNode: _m3uUrlFocus,
                      keyboardTitle: 'Playlist link',
                      decoration: const InputDecoration(
                        labelText: 'Playlist link',
                        hintText: 'http://example.com/playlist.m3u',
                        prefixIcon: Icon(Icons.link),
                      ),
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _epgUrlFocus.requestFocus(),
                    ),
                    const SizedBox(height: 12),
                    TvTextField(
                      controller: _epgUrlController,
                      focusNode: _epgUrlFocus,
                      keyboardTitle: 'Guide (EPG) link',
                      decoration: const InputDecoration(
                        labelText: 'Guide (EPG) link — optional',
                        hintText: 'Usually found automatically',
                        prefixIcon: Icon(Icons.event_note_outlined),
                      ),
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _connect(),
                    ),
                  ],
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
