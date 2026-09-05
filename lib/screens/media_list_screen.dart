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
      body: FutureBuilder<List<MediaItem>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          return CustomScrollView(
            slivers: [
              SliverAppBar.large(title: Text(widget.title)),
              if (snapshot.connectionState != ConnectionState.done)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                SliverFillRemaining(child: Center(child: Text('${snapshot.error}')))
              else if (snapshot.data!.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('Nothing found in this category.')),
                )
              else if (widget.gridView)
                SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 160,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.62,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => MediaPosterCard(item: snapshot.data![index]),
                      childCount: snapshot.data!.length,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  sliver: SliverList.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) => MediaTile(item: snapshot.data![index]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
