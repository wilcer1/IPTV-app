import 'package:flutter/material.dart';

import '../models/channel.dart';
import '../models/live_category.dart';
import '../services/xtream_api_client.dart';
import 'player_screen.dart';

class ChannelListScreen extends StatefulWidget {
  final XtreamApiClient client;
  final LiveCategory category;

  const ChannelListScreen({
    super.key,
    required this.client,
    required this.category,
  });

  @override
  State<ChannelListScreen> createState() => _ChannelListScreenState();
}

class _ChannelListScreenState extends State<ChannelListScreen> {
  late final Future<List<Channel>> _channelsFuture;

  @override
  void initState() {
    super.initState();
    _channelsFuture = widget.client.getLiveStreams(widget.category.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.category.name)),
      body: FutureBuilder<List<Channel>>(
        future: _channelsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }

          final channels = snapshot.data!;
          if (channels.isEmpty) {
            return const Center(child: Text('No channels in this category.'));
          }

          return ListView.builder(
            itemCount: channels.length,
            itemBuilder: (context, index) {
              final channel = channels[index];
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
