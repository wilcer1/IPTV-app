import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_app/models/login_config.dart';
import 'package:iptv_app/models/media_item.dart';
import 'package:iptv_app/models/series_details.dart';
import 'package:iptv_app/models/series_summary.dart';
import 'package:iptv_app/screens/home_feed_screen.dart';
import 'package:iptv_app/screens/series_detail_screen.dart';
import 'package:iptv_app/services/iptv_client.dart';
import 'package:iptv_app/services/watch_progress_store.dart';
import 'package:iptv_app/widgets/media_tile.dart';

MediaItem episode(int n) => MediaItem(
      id: 'ep$n',
      name: 'Pilot part $n',
      streamUrl: 'http://h/u/p/$n.mp4',
      seriesId: 'show',
      seriesTitle: 'The Show',
      season: 1,
      episode: n,
    );

class FakeClient implements IptvClient {
  final SeriesDetails details = SeriesDetails(
    name: 'The Show',
    seasons: [
      SeriesSeason(seasonNumber: '1', episodes: [episode(1), episode(2), episode(3)]),
    ],
  );

  @override
  LoginConfig get login => const M3uLogin(url: 'http://example.com/list.m3u');

  @override
  Future<SeriesDetails> getSeriesInfo(String seriesId) async => details;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const showLength = Duration(minutes: 45);
var scopeCounter = 0;

Future<WatchProgressStore> freshStore() async {
  FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});
  final store = WatchProgressStore.instance;
  await store.activate('ui-test-${scopeCounter++}');
  return store;
}

void main() {
  group('Home feed', () {
    testWidgets('explains itself when there is nothing to continue', (tester) async {
      await freshStore();
      await tester.pumpWidget(MaterialApp(
        home: HomeFeedScreen(client: FakeClient(), onBrowse: (_) {}),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Nothing to continue yet'), findsOneWidget);
      expect(find.text('Continue Watching'), findsNothing);
    });

    testWidgets('lists in-progress and up-next cards, and cards can be removed', (tester) async {
      final store = await freshStore();
      store.record(
        MediaItem(id: 'film', name: 'Some Film', streamUrl: 'http://h/film.mp4'),
        position: const Duration(minutes: 25),
        duration: const Duration(minutes: 100),
      );
      // Real time, not the test's fake clock, so the two entries get
      // different timestamps (a plain Future.delayed would hang here).
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      store.record(episode(1),
          position: const Duration(minutes: 44), duration: showLength, next: episode(2));

      await tester.pumpWidget(MaterialApp(
        home: HomeFeedScreen(client: FakeClient(), onBrowse: (_) {}),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Continue Watching'), findsOneWidget);
      expect(find.text('Some Film'), findsOneWidget);
      expect(find.text('1 h 15 min left'), findsOneWidget);
      // The show is represented by its next episode, titled by the show.
      expect(find.text('The Show'), findsOneWidget);
      expect(find.text('S1 E2 · Up next'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove from Continue Watching').first);
      await tester.pumpAndSettle();
      expect(find.text('The Show'), findsNothing);
      expect(find.text('Some Film'), findsOneWidget);
      await store.flush();
    });
  });

  group('Series page', () {
    testWidgets('offers Play for a show you haven\'t started', (tester) async {
      await freshStore();
      await tester.pumpWidget(MaterialApp(
        home: SeriesDetailScreen(
          client: FakeClient(),
          series: const SeriesSummary(seriesId: 'show', name: 'The Show'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Play S1 E1'), findsOneWidget);
    });

    testWidgets('offers Resume for an episode part-way through', (tester) async {
      final store = await freshStore();
      store.record(episode(2),
          position: const Duration(minutes: 20), duration: showLength, next: episode(3));

      await tester.pumpWidget(MaterialApp(
        home: SeriesDetailScreen(
          client: FakeClient(),
          series: const SeriesSummary(seriesId: 'show', name: 'The Show'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Resume S1 E2'), findsOneWidget);
      // That episode's row shows how much is left.
      expect(find.text('25 min left'), findsOneWidget);
      await store.flush();
    });

    testWidgets('offers the next episode once one is finished, and ticks it off', (tester) async {
      final store = await freshStore();
      store.record(episode(1),
          position: const Duration(minutes: 44), duration: showLength, next: episode(2));

      await tester.pumpWidget(MaterialApp(
        home: SeriesDetailScreen(
          client: FakeClient(),
          series: const SeriesSummary(seriesId: 'show', name: 'The Show'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Play S1 E2'), findsOneWidget);
      expect(find.text('Watched'), findsOneWidget);
      await store.flush();
    });
  });

  testWidgets('a movie row shows a progress bar and time left', (tester) async {
    final store = await freshStore();
    final film = MediaItem(id: 'film', name: 'Some Film', streamUrl: 'http://h/film.mp4');
    store.record(film,
        position: const Duration(minutes: 40), duration: const Duration(minutes: 100));

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MediaTile(item: film))));
    await tester.pumpAndSettle();

    expect(find.text('1 h left'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await store.flush();
  });

  testWidgets('live channels never show progress', (tester) async {
    await freshStore();
    final channel = MediaItem(name: 'Sky Sports', streamUrl: 'http://h/live/1.ts', isLive: true);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MediaTile(item: channel))));
    await tester.pumpAndSettle();

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Watched'), findsNothing);
  });
}
