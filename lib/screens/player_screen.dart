import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/media_item.dart';
import '../services/favorites_store.dart';

class PlayerScreen extends StatefulWidget {
  final MediaItem item;

  const PlayerScreen({super.key, required this.item});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _player.open(Media(widget.item.streamUrl));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.item.name),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          ListenableBuilder(
            listenable: FavoritesStore.instance,
            builder: (context, _) {
              final isFavorite =
                  FavoritesStore.instance.isFavorite(widget.item.streamUrl);
              return IconButton(
                icon: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  color: isFavorite ? Colors.amber : Colors.white,
                ),
                onPressed: () => FavoritesStore.instance.toggle(widget.item),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Video(controller: _controller),
            StreamBuilder<bool>(
              stream: _player.stream.buffering,
              initialData: true,
              builder: (context, snapshot) {
                if (snapshot.data != true) return const SizedBox.shrink();
                return const CircularProgressIndicator(color: Colors.white);
              },
            ),
          ],
        ),
      ),
    );
  }
}
