import '../models/account_info.dart';
import '../models/category.dart';
import '../models/epg_program.dart';
import '../models/login_config.dart';
import '../models/media_item.dart';
import '../models/series_details.dart';
import '../models/series_summary.dart';

/// Everything the UI needs from a provider, regardless of whether it is an
/// Xtream Codes panel or a plain M3U playlist.
abstract class IptvClient {
  LoginConfig get login;

  /// Shown as the headline and subline on the Account tab.
  String get accountTitle;
  String get accountSubtitle;

  Future<void> authenticate();

  /// Null when the source has no concept of an account (plain M3U).
  Future<AccountInfo?> getAccountInfo();

  Future<List<Category>> getLiveCategories();
  Future<List<MediaItem>> getLiveStreams([String? categoryId]);
  Future<List<Category>> getVodCategories();
  Future<List<MediaItem>> getVodStreams([String? categoryId]);
  Future<List<Category>> getSeriesCategories();
  Future<List<SeriesSummary>> getSeries([String? categoryId]);
  Future<SeriesDetails> getSeriesInfo(String seriesId);
  Future<List<EpgProgram>> getFullEpg();
}
