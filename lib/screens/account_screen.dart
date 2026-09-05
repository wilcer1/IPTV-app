import 'package:flutter/material.dart';

import '../models/account_info.dart';
import '../services/credentials_store.dart';
import '../services/xtream_api_client.dart';
import 'login_screen.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.dns),
            title: const Text('Host'),
            subtitle: Text(credentials.host),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Username'),
            subtitle: Text(credentials.username),
          ),
          const Divider(),
          FutureBuilder<AccountInfo>(
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
                  child: Text('Could not load account info: ${snapshot.error}'),
                );
              }

              final info = snapshot.data!;
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.verified_user),
                    title: const Text('Status'),
                    subtitle: Text(info.status ?? 'Unknown'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.event),
                    title: const Text('Expires'),
                    subtitle: Text(
                      info.expiresAt == null
                          ? 'No expiration'
                          : '${info.expiresAt!.toLocal()}'.split('.').first,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.cast_connected),
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
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Log out'),
            ),
          ),
        ],
      ),
    );
  }
}
