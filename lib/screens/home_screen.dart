import 'package:flutter/material.dart';

import '../services/xtream_api_client.dart';
import 'account_screen.dart';
import 'categories_screen.dart';
import 'favorites_screen.dart';
import 'media_list_screen.dart';
import 'search_screen.dart';
import 'series_list_screen.dart';

class _NavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

const _destinations = [
  _NavDestination(icon: Icons.live_tv_outlined, selectedIcon: Icons.live_tv, label: 'Live TV'),
  _NavDestination(icon: Icons.movie_outlined, selectedIcon: Icons.movie, label: 'Movies'),
  _NavDestination(
      icon: Icons.video_library_outlined, selectedIcon: Icons.video_library, label: 'Series'),
  _NavDestination(icon: Icons.search, selectedIcon: Icons.search, label: 'Search'),
  _NavDestination(icon: Icons.star_outline, selectedIcon: Icons.star, label: 'Favorites'),
  _NavDestination(
      icon: Icons.account_circle_outlined, selectedIcon: Icons.account_circle, label: 'Account'),
];

const _wideBreakpoint = 640.0;
const _extendedBreakpoint = 1000.0;

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
        icon: Icons.live_tv,
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
        icon: Icons.movie,
        fetchCategories: client.getVodCategories,
        onCategoryTap: (context, category) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MediaListScreen(
                title: category.name,
                gridView: true,
                fetchItems: () => client.getVodStreams(category.id),
              ),
            ),
          );
        },
      ),
      CategoriesScreen(
        title: 'Series',
        icon: Icons.video_library,
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
      AccountScreen(client: client),
    ];

    final body = IndexedStack(index: _index, children: tabs);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _wideBreakpoint) {
          return Scaffold(
            body: body,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
              destinations: [
                for (final d in _destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                  ),
              ],
            ),
          );
        }

        final extended = constraints.maxWidth >= _extendedBreakpoint;
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (value) => setState(() => _index = value),
                extended: extended,
                minExtendedWidth: 220,
                labelType:
                    extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Icon(
                    Icons.live_tv_rounded,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                destinations: [
                  for (final d in _destinations)
                    NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: Text(d.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }
}
