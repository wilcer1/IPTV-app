import 'package:flutter/material.dart';

import '../models/live_category.dart';
import '../services/xtream_api_client.dart';
import 'channel_list_screen.dart';
import 'search_screen.dart';

class CategoryListScreen extends StatefulWidget {
  final XtreamApiClient client;

  const CategoryListScreen({super.key, required this.client});

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  late final Future<List<LiveCategory>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = widget.client.getLiveCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live TV categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search channels',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SearchScreen(client: widget.client),
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<LiveCategory>>(
        future: _categoriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }

          final categories = snapshot.data!;
          if (categories.isEmpty) {
            return const Center(child: Text('No categories found.'));
          }

          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return ListTile(
                title: Text(category.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChannelListScreen(
                        client: widget.client,
                        category: category,
                      ),
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
