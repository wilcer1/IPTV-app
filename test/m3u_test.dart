import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_app/models/xtream_credentials.dart';
import 'package:iptv_app/services/m3u_parser.dart';

const _playlist = '''
﻿#EXTM3U url-tvg="http://epg.example.com/guide.xml.gz,http://other.example.com/x.xml"
#EXTINF:-1 tvg-id="bbc1.uk" tvg-logo="http://logo/bbc1.png" group-title="News, UK",BBC One
http://host/live/bbc1.m3u8
#EXTINF:-1 group-title="Sports",Sky Sports 1
#EXTVLCOPT:http-user-agent=Test
http://host/live/sky1.ts
#EXTINF:-1,No Group Channel
http://host/live/nogroup.ts
#EXTINF:-1 group-title="Movies",Some Film (2020)
http://host/vod/some-film.mkv
#EXTINF:-1 tvg-logo="http://logo/bb.png" group-title="Shows",Breaking Bad S01E01
http://host/vod/bb101.mp4
#EXTINF:-1 group-title="Shows",Breaking Bad S01E02
http://host/vod/bb102.mp4
#EXTINF:-1 group-title="Shows",Breaking Bad S02E01
http://host/vod/bb201.mp4
#EXTINF:-1 group-title="Xtream",Xtream Movie
http://host:8080/movie/user/pass/123.mp4
''';

void main() {
  group('parseM3u', () {
    final playlist = parseM3u(_playlist);

    test('reads the EPG url from the header, taking the first of several', () {
      expect(playlist.epgUrl, 'http://epg.example.com/guide.xml.gz');
    });

    test('keeps commas inside group-title out of the channel name', () {
      final bbc = playlist.entries.first;
      expect(bbc.name, 'BBC One');
      expect(bbc.group, 'News, UK');
      expect(bbc.tvgId, 'bbc1.uk');
      expect(bbc.logo, 'http://logo/bbc1.png');
    });

    test('ignores #EXTVLCOPT lines and still pairs name with url', () {
      final sky = playlist.entries.firstWhere((e) => e.name == 'Sky Sports 1');
      expect(sky.url, 'http://host/live/sky1.ts');
    });

    test('puts group-less entries in Uncategorized', () {
      final entry = playlist.entries.firstWhere((e) => e.name == 'No Group Channel');
      expect(entry.group, 'Uncategorized');
    });
  });

  group('buildM3uLibrary', () {
    final library = buildM3uLibrary(_playlist);

    test('sorts entries into live, movies and series', () {
      expect(library.liveByCategory.values.expand((e) => e).map((e) => e.name),
          containsAll(['BBC One', 'Sky Sports 1', 'No Group Channel']));
      expect(library.vodByCategory.values.expand((e) => e).map((e) => e.name),
          containsAll(['Some Film (2020)', 'Xtream Movie']));
      expect(library.seriesCategories.map((c) => c.name), ['Shows']);
    });

    test('live entries are flagged live and carry their EPG id', () {
      final bbc = library.liveByCategory['News, UK']!.single;
      expect(bbc.isLive, isTrue);
      expect(bbc.epgChannelId, 'bbc1.uk');
      expect(library.vodByCategory['Movies']!.single.isLive, isFalse);
    });

    test('groups episodes into one series with ordered seasons', () {
      final summaries = library.seriesByCategory['Shows']!;
      expect(summaries, hasLength(1));
      expect(summaries.single.name, 'Breaking Bad');
      expect(summaries.single.coverUrl, 'http://logo/bb.png');

      final details = library.seriesDetails[summaries.single.seriesId]!;
      expect(details.seasons.map((s) => s.seasonNumber), ['1', '2']);
      expect(details.seasons.first.episodes, hasLength(2));
    });

    test('episodes carry what history needs, in watching order', () {
      final id = library.seriesByCategory['Shows']!.single.seriesId;
      final episodes = library.seriesDetails[id]!.allEpisodes;

      expect(episodes.map((e) => (e.season, e.episode)), [(1, 1), (1, 2), (2, 1)]);
      expect(episodes.first.seriesId, id);
      expect(episodes.first.seriesTitle, 'Breaking Bad');
      expect(episodes.first.episodeLabel, 'S1 E1');
      expect(episodes.map((e) => e.id).toSet(), hasLength(3));
    });
  });

  group('XtreamCredentials.tryFromPlaylistUrl', () {
    test('recognises a get.php playlist link', () {
      final creds = XtreamCredentials.tryFromPlaylistUrl(
        'http://example.com:8080/get.php?username=bob&password=secret&type=m3u_plus&output=ts',
      );
      expect(creds?.host, 'http://example.com:8080');
      expect(creds?.username, 'bob');
      expect(creds?.password, 'secret');
    });

    test('keeps a path prefix in front of get.php', () {
      final creds = XtreamCredentials.tryFromPlaylistUrl(
        'https://example.com/panel/get.php?username=a&password=b',
      );
      expect(creds?.host, 'https://example.com/panel');
    });

    test('returns null for ordinary playlists', () {
      expect(XtreamCredentials.tryFromPlaylistUrl('http://example.com/list.m3u'), isNull);
      expect(XtreamCredentials.tryFromPlaylistUrl('http://example.com/get.php?id=5'), isNull);
    });
  });
}
