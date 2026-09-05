import 'package:flutter/material.dart';

import '../services/xtream_api_client.dart';
import 'categories_screen.dart';
import 'favorites_screen.dart';
import 'media_list_screen.dart';
import 'search_screen.dart';
import 'series_list_screen.dart';

class HomeScreen extends StatefulWidget {
  final XtreamApiClient client;

  const HomeScreen({super.key, required this.client});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final client = widget.client;

    final tabs = [
      CategoriesScreen(
        title: 'Live TV',
        fetchCategories: client.getLiveCategories,
        onCategoryTap: (context, category) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MediaListScreen(
                title: category.name,
                fetchItems: () => client.getLiveStreams(category.id),
              ),
            ),
          );
        },
      ),
      CategoriesScreen(
        title: 'Movies',
        fetchCategories: client.getVodCategories,
        onCategoryTap: (context, category) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MediaListScreen(
                title: category.name,
                fetchItems: () => client.getVodStreams(category.id),
              ),
            ),
          );
        },
      ),
      CategoriesScreen(
        title: 'Series',
        fetchCategories: client.getSeriesCategories,
        onCategoryTap: (context, category) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SeriesListScreen(
                title: category.name,
                client: client,
                fetchSeries: () => client.getSeries(category.id),
              ),
            ),
          );
        },
      ),
      SearchScreen(client: client),
      const FavoritesScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.live_tv), label: 'Live TV'),
          NavigationDestination(icon: Icon(Icons.movie), label: 'Movies'),
          NavigationDestination(icon: Icon(Icons.video_library), label: 'Series'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.star), label: 'Favorites'),
        ],
      ),
    );
  }
}
