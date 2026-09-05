import 'package:flutter/material.dart';

import '../models/channel.dart';
import '../services/xtream_api_client.dart';
import 'player_screen.dart';

class SearchScreen extends StatefulWidget {
  final XtreamApiClient client;

  const SearchScreen({super.key, required this.client});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final Future<List<Channel>> _allChannelsFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _allChannelsFuture = widget.client.getLiveStreams();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search channels...',
            border: InputBorder.none,
          ),
          style: Theme.of(context).appBarTheme.titleTextStyle ??
              const TextStyle(fontSize: 18),
          onChanged: (value) => setState(() => _query = value),
        ),
      ),
      body: FutureBuilder<List<Channel>>(
        future: _allChannelsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }

          final query = _query.trim().toLowerCase();
          final results = query.isEmpty
              ? const <Channel>[]
              : snapshot.data!
                  .where((c) => c.name.toLowerCase().contains(query))
                  .toList();

          if (query.isEmpty) {
            return const Center(child: Text('Start typing to search channels.'));
          }
          if (results.isEmpty) {
            return const Center(child: Text('No matching channels.'));
          }

          return ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final channel = results[index];
              return ListTile(
                leading: channel.logoUrl != null
                    ? Image.network(
                        channel.logoUrl!,
                        width: 40,
                        height: 40,
                        errorBuilder: (_, _, _) => const Icon(Icons.tv),
                      )
                    : const Icon(Icons.tv),
                title: Text(channel.name),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PlayerScreen(channel: channel),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
