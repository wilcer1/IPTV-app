import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeviceInfo {
  DeviceInfo._();

  static const _channel = MethodChannel('iptv_app/device');
  static Future<bool>? _isTvFuture;
  static bool? _isTvCached;

  /// Whether this is running on an actual Android TV / Google TV device
  /// (not just a wide window). Cached after the first call; safe to call
  /// repeatedly and cheap once resolved.
  static Future<bool> isTv() => _isTvFuture ??= _detectIsTv();

  /// Synchronous read of the cached result, if [isTv] has already resolved
  /// (main() awaits it before runApp, so it normally has by the time any
  /// widget builds). Defaults to false while still unresolved.
  static bool get isTvSync => _isTvCached ?? false;

  static Future<bool> _detectIsTv() async {
    if (defaultTargetPlatform != TargetPlatform.android) return _isTvCached = false;
    try {
      return _isTvCached = await _channel.invokeMethod<bool>('isTv') ?? false;
    } on PlatformException {
      return _isTvCached = false;
    } on MissingPluginException {
      return _isTvCached = false;
    }
  }
}
