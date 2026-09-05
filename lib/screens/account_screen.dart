import 'package:flutter/material.dart';

import '../models/account_info.dart';
import '../services/credentials_store.dart';
import '../services/theme_controller.dart';
import '../services/xtream_api_client.dart';
import 'login_screen.dart';
import 'pair_send_screen.dart';

class AccountScreen extends StatefulWidget {
  final XtreamApiClient client;

  const AccountScreen({super.key, required this.client});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final Future<AccountInfo> _accountFuture;

  @override
  void initState() {
    super.initState();
    _accountFuture = widget.client.getAccountInfo();
  }

  Future<void> _logout() async {
    await CredentialsStore().clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final credentials = widget.client.credentials;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('Account')),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: colorScheme.primaryContainer,
                        child: Icon(
                          Icons.person,
                          size: 40,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        credentials.username,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        credentials.host,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: FutureBuilder<AccountInfo>(
                    future: _accountFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Could not load account info: ${snapshot.error}',
                          ),
                        );
                      }

                      final info = snapshot.data!;
                      return Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.verified_user_outlined),
                            title: const Text('Status'),
                            subtitle: Text(info.status ?? 'Unknown'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.event_outlined),
                            title: const Text('Expires'),
                            subtitle: Text(
                              info.expiresAt == null
                                  ? 'No expiration'
                                  : '${info.expiresAt!.toLocal()}'
                                        .split('.')
                                        .first,
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.cast_connected_outlined),
                            title: const Text('Connections'),
                            subtitle: Text(
                              '${info.activeConnections ?? '?'} / ${info.maxConnections ?? '?'} active',
                            ),
                          ),
                          if (info.isTrial)
                            const ListTile(
                              leading: Icon(Icons.info_outline),
                              title: Text('Trial account'),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListenableBuilder(
                    listenable: ThemeController.instance,
                    builder: (context, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              'Appearance',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: SegmentedButton<ThemeMode>(
                              segments: const [
                                ButtonSegment(
                                  value: ThemeMode.system,
                                  icon: Icon(Icons.brightness_auto),
                                  label: Text('System'),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.light,
                                  icon: Icon(Icons.light_mode),
                                  label: Text('Light'),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.dark,
                                  icon: Icon(Icons.dark_mode),
                                  label: Text('Dark'),
                                ),
                              ],
                              selected: {ThemeController.instance.mode},
                              onSelectionChanged: (selection) => ThemeController
                                  .instance
                                  .setMode(selection.first),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.tv_outlined),
                    title: const Text('Add a device'),
                    subtitle: const Text('Sign in on a TV without typing your credentials'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PairSendScreen(credentials: credentials),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Log out'),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
