import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/login_config.dart';
import '../models/media_item.dart';

/// Watch history is per account: it must not leak from one provider login
/// into another, but should survive logging out and back into the same one.
String watchScopeFor(LoginConfig login) {
  return switch (login) {
    XtreamLogin(:final credentials) => 'x:${fnv1a('${credentials.host}|${credentials.username}')}',
    M3uLogin(:final url) => 'm:${fnv1a(url)}',
  };
}

String describeRemaining(Duration remaining) {
  final minutes = (remaining.inSeconds / 60).ceil();
  if (minutes < 1) return 'Less than a minute left';
  if (minutes < 60) return '$minutes min left';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours h left' : '$hours h $rest min left';
}

class WatchEntry {
  final MediaItem item;
  final int positionMs;
  final int durationMs;
  final bool completed;
  final DateTime updatedAt;

  /// The episode that follows this one, remembered so "Up next" still works
  /// after this one is finished and we're no longer inside the series screen.
  final MediaItem? next;

  const WatchEntry({
    required this.item,
    required this.positionMs,
    required this.durationMs,
    required this.completed,
    required this.updatedAt,
    this.next,
  });

  double get fraction =>
      durationMs <= 0 ? 0 : (positionMs / durationMs).clamp(0.0, 1.0).toDouble();

  Duration get remaining =>
      Duration(milliseconds: (durationMs - positionMs).clamp(0, durationMs));

  WatchEntry withoutNext() => WatchEntry(
        item: item,
        positionMs: positionMs,
        durationMs: durationMs,
        completed: completed,
        updatedAt: updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'item': item.toJson(),
        'positionMs': positionMs,
        'durationMs': durationMs,
        'completed': completed,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'next': next?.toJson(),
      };

  factory WatchEntry.fromJson(Map<String, dynamic> json) => WatchEntry(
        item: MediaItem.fromJson(json['item'] as Map<String, dynamic>),
        positionMs: json['positionMs'] as int,
        durationMs: json['durationMs'] as int,
        completed: json['completed'] as bool,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int),
        next: json['next'] == null
            ? null
            : MediaItem.fromJson(json['next'] as Map<String, dynamic>),
      );
}

/// One card in the "Continue Watching" row: either something part-way
/// through, or the next episode of a show whose last episode was finished.
class ContinueItem {
  final MediaItem item;
  final WatchEntry? entry;
  final bool upNext;
  final DateTime at;

  const ContinueItem({
    required this.item,
    required this.entry,
    required this.upNext,
    required this.at,
  });

  double? get fraction => upNext ? null : entry?.fraction;
  Duration? get remaining => upNext ? null : entry?.remaining;
}

class WatchProgressStore extends ChangeNotifier {
  WatchProgressStore();

  static final WatchProgressStore instance = WatchProgressStore();

  static const _storageKey = 'watch_history';
  static const _maxEntries = 200;
  static const _saveDelay = Duration(seconds: 3);

  /// Past this fraction an item counts as watched (credits are rolling).
  static const completeAt = 0.92;

  /// Ignore accidental taps: nothing is remembered until you've really
  /// started watching.
  static const minTrackedPosition = Duration(seconds: 10);

  /// Clips shorter than this (trailers, bumpers) aren't tracked at all.
  static const minTrackedDuration = Duration(seconds: 60);

  // Encrypted at rest because the stored stream URLs embed the Xtream
  // username and password.
  static const _storage = FlutterSecureStorage();

  final Map<String, WatchEntry> _entries = {};
  String? _scope;
  Timer? _saveTimer;

  Future<void> activate(String scope) async {
    if (_scope == scope) return;
    _scope = scope;
    _entries.clear();
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw != null) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        if (json['scope'] == scope) {
          for (final e in json['entries'] as List<dynamic>) {
            final entry = WatchEntry.fromJson(e as Map<String, dynamic>);
            _entries[entry.item.id] = entry;
          }
        }
      }
    } catch (_) {
      // Unreadable or from an incompatible version: start fresh rather than
      // fail to launch.
    }
    notifyListeners();
  }

  WatchEntry? entryFor(String id) => _entries[id];

  bool isCompleted(String id) => _entries[id]?.completed ?? false;

  /// Fraction watched for something in progress; null if untouched or done.
  double? progressFraction(String id) {
    final entry = _entries[id];
    if (entry == null || entry.completed) return null;
    if (entry.positionMs < minTrackedPosition.inMilliseconds) return null;
    return entry.fraction;
  }

  void record(
    MediaItem item, {
    required Duration position,
    required Duration duration,
    MediaItem? next,
  }) {
    if (item.isLive || _scope == null || duration < minTrackedDuration) return;

    final existing = _entries[item.id];
    final now = DateTime.now();
    final finished = position.inMilliseconds / duration.inMilliseconds >= completeAt;

    if (finished) {
      _entries[item.id] = WatchEntry(
        item: item,
        // A finished item replays from the start, like Netflix.
        positionMs: 0,
        durationMs: duration.inMilliseconds,
        completed: true,
        updatedAt: now,
        next: next ?? existing?.next,
      );
    } else {
      if (position < minTrackedPosition && existing == null) return;
      _entries[item.id] = WatchEntry(
        item: item,
        positionMs: position.inMilliseconds,
        durationMs: duration.inMilliseconds,
        completed: false,
        updatedAt: now,
        next: next ?? existing?.next,
      );
    }

    _trim();
    notifyListeners();
    _scheduleSave();
  }

  /// Forget one item's progress (e.g. "Start over").
  void remove(String id) {
    if (_entries.remove(id) == null) return;
    notifyListeners();
    _scheduleSave();
  }

  /// "Remove from Continue Watching". For a series this clears the in-progress
  /// episode and the "up next" suggestion, but keeps finished episodes marked
  /// as watched.
  void dismiss(ContinueItem card) {
    final seriesId = card.item.seriesId;
    if (seriesId == null) {
      _entries.remove(card.item.id);
    } else {
      for (final id in _entries.keys.toList()) {
        final entry = _entries[id]!;
        if (entry.item.seriesId != seriesId) continue;
        if (entry.completed) {
          _entries[id] = entry.withoutNext();
        } else {
          _entries.remove(id);
        }
      }
    }
    notifyListeners();
    _scheduleSave();
  }

  Iterable<ContinueItem> _candidates() sync* {
    for (final entry in _entries.values) {
      if (!entry.completed) {
        if (entry.positionMs >= minTrackedPosition.inMilliseconds) {
          yield ContinueItem(
            item: entry.item,
            entry: entry,
            upNext: false,
            at: entry.updatedAt,
          );
        }
      } else if (entry.next != null && !_entries.containsKey(entry.next!.id)) {
        yield ContinueItem(
          item: entry.next!,
          entry: null,
          upNext: true,
          at: entry.updatedAt,
        );
      }
    }
  }

  /// Newest activity for a show, whether part-way through or "up next".
  ContinueItem? latestForSeries(String seriesId) {
    ContinueItem? best;
    for (final c in _candidates()) {
      if (c.item.seriesId != seriesId) continue;
      if (best == null || c.at.isAfter(best.at)) best = c;
    }
    return best;
  }

  /// Most recent first, one card per show (like Netflix), capped at 20.
  List<ContinueItem> get continueWatching {
    final byKey = <String, ContinueItem>{};
    for (final c in _candidates()) {
      final key = c.item.seriesId != null ? 's:${c.item.seriesId}' : 'i:${c.item.id}';
      final current = byKey[key];
      if (current == null || c.at.isAfter(current.at)) byKey[key] = c;
    }
    final list = byKey.values.toList()..sort((a, b) => b.at.compareTo(a.at));
    return list.take(20).toList();
  }

  void _trim() {
    if (_entries.length <= _maxEntries) return;
    final oldestFirst = _entries.values.toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    for (final entry in oldestFirst.take(_entries.length - _maxEntries)) {
      _entries.remove(entry.item.id);
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, flush);
  }

  /// Write to disk now; called when leaving the player so nothing is lost.
  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    final scope = _scope;
    if (scope == null) return;
    try {
      await _storage.write(
        key: _storageKey,
        value: jsonEncode({
          'scope': scope,
          'entries': [for (final e in _entries.values) e.toJson()],
        }),
      );
    } catch (_) {
      // Losing a progress tick is not worth surfacing an error.
    }
  }
}
