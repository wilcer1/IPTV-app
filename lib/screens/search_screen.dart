import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../services/xtream_api_client.dart';
import '../widgets/media_tile.dart';

class SearchScreen extends StatefulWidget {
  final XtreamApiClient client;

  const SearchScreen({super.key, required this.client});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final Future<List<MediaItem>> _allChannelsFuture;
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
          decoration: const InputDecoration(
            hintText: 'Search live channels...',
            border: InputBorder.none,
          ),
          style: Theme.of(context).appBarTheme.titleTextStyle ??
              const TextStyle(fontSize: 18),
          onChanged: (value) => setState(() => _query = value),
        ),
      ),
      body: FutureBuilder<List<MediaItem>>(
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
              ? const <MediaItem>[]
              : snapshot.data!
                  .where((c) => c.name.toLowerCase().contains(query))
                  .toList();

          if (query.isEmpty) {
            return const Center(child: Text('Start typing to search live channels.'));
          }
          if (results.isEmpty) {
            return const Center(child: Text('No matching channels.'));
          }

          return ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) => MediaTile(item: results[index]),
          );
        },
      ),
    );
  }
}
