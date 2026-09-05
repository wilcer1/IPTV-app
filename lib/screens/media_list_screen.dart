import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../widgets/media_poster_card.dart';
import '../widgets/media_tile.dart';

class MediaListScreen extends StatefulWidget {
  final String title;
  final Future<List<MediaItem>> Function() fetchItems;
  final bool gridView;

  const MediaListScreen({
    super.key,
    required this.title,
    required this.fetchItems,
    this.gridView = false,
  });

  @override
  State<MediaListScreen> createState() => _MediaListScreenState();
}

class _MediaListScreenState extends State<MediaListScreen> {
  late final Future<List<MediaItem>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = widget.fetchItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<List<MediaItem>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }

          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(child: Text('Nothing found in this category.'));
          }

          if (widget.gridView) {
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.62,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) => MediaPosterCard(item: items[index]),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            itemBuilder: (context, index) => MediaTile(item: items[index]),
          );
        },
      ),
    );
  }
}
