import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_item.dart';

class FavoritesStore extends ChangeNotifier {
  FavoritesStore._internal();
  static final FavoritesStore instance = FavoritesStore._internal();

  static const _prefsKey = 'favorite_channels';

  final Map<String, MediaItem> _favorites = {};
  bool _loaded = false;

  List<MediaItem> get all => _favorites.values.toList();

  bool isFavorite(String streamUrl) => _favorites.containsKey(streamUrl);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    for (final entry in raw) {
      final item = MediaItem.fromJson(jsonDecode(entry) as Map<String, dynamic>);
      _favorites[item.streamUrl] = item;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> toggle(MediaItem item) async {
    if (_favorites.containsKey(item.streamUrl)) {
      _favorites.remove(item.streamUrl);
    } else {
      _favorites[item.streamUrl] = item;
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final raw = _favorites.values.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(_prefsKey, raw);
  }
}
