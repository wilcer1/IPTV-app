import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_app/models/media_item.dart';
import 'package:iptv_app/services/watch_progress_store.dart';

MediaItem movie(String id) =>
    MediaItem(id: id, name: 'Movie $id', streamUrl: 'http://h/u/p/$id.mp4');

MediaItem episode(int n, {String series = 'show1'}) => MediaItem(
      id: '$series-ep$n',
      name: 'Episode $n',
      streamUrl: 'http://h/u/p/$series-$n.mp4',
      seriesId: series,
      seriesTitle: 'Show $series',
      season: 1,
      episode: n,
    );

const movieLength = Duration(minutes: 100);
const showLength = Duration(minutes: 45);

Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  late Map<String, String> disk;
  late WatchProgressStore store;

  setUp(() async {
    disk = {};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(disk);
    store = WatchProgressStore();
    await store.activate('account-1');
  });

  group('what gets remembered', () {
    test('ignores the first seconds, so an accidental tap leaves no trace', () {
      store.record(movie('a'), position: const Duration(seconds: 6), duration: movieLength);
      expect(store.continueWatching, isEmpty);
      expect(store.entryFor('a'), isNull);
    });

    test('ignores clips too short to be a real programme, and live TV', () {
      store.record(movie('trailer'),
          position: const Duration(seconds: 30), duration: const Duration(seconds: 45));
      store.record(
        MediaItem(id: 'live', name: 'Channel', streamUrl: 'http://h/live', isLive: true),
        position: const Duration(minutes: 30),
        duration: const Duration(hours: 2),
      );
      expect(store.continueWatching, isEmpty);
    });

    test('shows a started movie with how far through it is', () {
      store.record(movie('a'), position: const Duration(minutes: 25), duration: movieLength);

      final card = store.continueWatching.single;
      expect(card.item.id, 'a');
      expect(card.upNext, isFalse);
      expect(card.fraction, closeTo(0.25, 0.001));
      expect(card.remaining, const Duration(minutes: 75));
      expect(store.progressFraction('a'), closeTo(0.25, 0.001));
    });

    test('lists the most recently watched first', () async {
      store.record(movie('old'), position: const Duration(minutes: 20), duration: movieLength);
      await tick();
      store.record(movie('new'), position: const Duration(minutes: 20), duration: movieLength);

      expect(store.continueWatching.map((c) => c.item.id), ['new', 'old']);
    });
  });

  group('finishing things', () {
    test('past 92% counts as watched and drops out of Continue Watching', () {
      store.record(movie('a'), position: const Duration(minutes: 95), duration: movieLength);

      expect(store.isCompleted('a'), isTrue);
      expect(store.progressFraction('a'), isNull);
      expect(store.continueWatching, isEmpty);
      // Replays from the beginning next time, like Netflix.
      expect(store.entryFor('a')!.positionMs, 0);
    });

    test('just short of the threshold is still in progress', () {
      store.record(movie('a'), position: const Duration(minutes: 90), duration: movieLength);
      expect(store.isCompleted('a'), isFalse);
      expect(store.continueWatching, hasLength(1));
    });

    test('finishing an episode offers the next one as "up next"', () {
      store.record(episode(1),
          position: const Duration(minutes: 44), duration: showLength, next: episode(2));

      final card = store.continueWatching.single;
      expect(card.upNext, isTrue);
      expect(card.item.id, 'show1-ep2');
      expect(card.fraction, isNull);
    });

    test('the last episode of a show offers nothing further', () {
      store.record(episode(8), position: const Duration(minutes: 44), duration: showLength);
      expect(store.continueWatching, isEmpty);
    });

    test('starting the next episode replaces the "up next" card, one card per show', () async {
      store.record(episode(1),
          position: const Duration(minutes: 44), duration: showLength, next: episode(2));
      await tick();
      store.record(episode(2),
          position: const Duration(minutes: 10), duration: showLength, next: episode(3));

      final card = store.continueWatching.single;
      expect(card.item.id, 'show1-ep2');
      expect(card.upNext, isFalse);
    });

    test('different shows each get their own card', () async {
      store.record(episode(1, series: 'a'),
          position: const Duration(minutes: 10), duration: showLength);
      await tick();
      store.record(episode(1, series: 'b'),
          position: const Duration(minutes: 10), duration: showLength);

      expect(store.continueWatching.map((c) => c.item.seriesId), ['b', 'a']);
    });
  });

  group('series helpers', () {
    test('latestForSeries finds where to resume, or the up-next episode', () {
      expect(store.latestForSeries('show1'), isNull);

      store.record(episode(3),
          position: const Duration(minutes: 20), duration: showLength, next: episode(4));
      expect(store.latestForSeries('show1')!.item.id, 'show1-ep3');
      expect(store.latestForSeries('show1')!.upNext, isFalse);
    });

    test('dismissing a show clears its card but keeps watched marks', () {
      store.record(episode(1),
          position: const Duration(minutes: 44), duration: showLength, next: episode(2));
      expect(store.continueWatching, hasLength(1));

      store.dismiss(store.continueWatching.single);

      expect(store.continueWatching, isEmpty);
      expect(store.isCompleted('show1-ep1'), isTrue);
    });

    test('"start over" forgets the item', () {
      store.record(movie('a'), position: const Duration(minutes: 30), duration: movieLength);
      store.remove('a');
      expect(store.entryFor('a'), isNull);
    });
  });

  group('persistence', () {
    test('survives a restart for the same account', () async {
      store.record(episode(2),
          position: const Duration(minutes: 12), duration: showLength, next: episode(3));
      await store.flush();

      final restarted = WatchProgressStore();
      await restarted.activate('account-1');

      final card = restarted.continueWatching.single;
      expect(card.item.id, 'show1-ep2');
      expect(card.item.season, 1);
      expect(card.item.episode, 2);
      expect(restarted.entryFor('show1-ep2')!.next!.id, 'show1-ep3');
    });

    test('one account never sees another account\'s history', () async {
      store.record(movie('a'), position: const Duration(minutes: 30), duration: movieLength);
      await store.flush();

      final other = WatchProgressStore();
      await other.activate('account-2');
      expect(other.continueWatching, isEmpty);
    });

    test('is stored encrypted, not in plain preferences', () async {
      store.record(movie('a'), position: const Duration(minutes: 30), duration: movieLength);
      await store.flush();
      expect(disk.keys, contains('watch_history'));
    });

    test('a corrupt save is ignored rather than crashing launch', () async {
      disk['watch_history'] = '{not json';
      final fresh = WatchProgressStore();
      await fresh.activate('account-1');
      expect(fresh.continueWatching, isEmpty);
    });
  });

  test('ids are stable and never contain credentials', () {
    final a = MediaItem(name: 'x', streamUrl: 'http://host/movie/user/secret/1.mp4');
    final b = MediaItem(name: 'x', streamUrl: 'http://host/movie/user/secret/1.mp4');
    expect(a.id, b.id);
    expect(a.id, isNot(contains('secret')));
    expect(a.id, isNot(contains('user')));
  });
}
