import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/media_item.dart';
import '../services/favorites_store.dart';

class PlayerScreen extends StatefulWidget {
  final MediaItem item;

  const PlayerScreen({super.key, required this.item});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  // How long buffering can stall before we assume the connection is stuck
  // and reopen it. Xtream live streams are commonly served as a
  // moving-window HLS playlist rather than a true endless stream: mpv treats
  // whatever window it has fetched as "the whole file", so once playback
  // catches up to it, it either stalls or reports completion instead of
  // continuing. Reopening re-fetches the playlist at the current live edge.
  static const _stallTimeout = Duration(seconds: 15);

  // How long the top bar stays visible after the last interaction, matching
  // media_kit's own built-in video controls so both fade together.
  static const _controlsHideDelay = Duration(seconds: 4);

  // Reopening the stream tears down and recreates the hardware decoder,
  // which is expensive and briefly stutters playback. Without a cooldown,
  // the `completed` stream can flip again during that same transition —
  // observed on real hardware as the decoder being torn down and rebuilt
  // twice within ~1 second, which is what "laggy" playback actually was.
  static const _reopenCooldown = Duration(seconds: 10);

  late final Player _player;
  late final VideoController _controller;
  StreamSubscription<bool>? _completedSubscription;
  StreamSubscription<bool>? _bufferingSubscription;
  Timer? _stallTimer;
  Timer? _hideControlsTimer;
  bool _controlsVisible = true;
  DateTime? _lastReopen;

  @override
  void initState() {
    super.initState();
    _player = Player();
    // "mediacodec-copy" was tried here to fix an audio/video sync
    // complaint, but it explicitly copies every decoded frame from the
    // hardware decoder into a CPU-accessible buffer instead of importing
    // it directly as a GPU texture — a documented fallback path, not a
    // performance mode. On the Chromecast HD's weak SoC that showed up as
    // very laggy/low-fps playback, confirmed on real hardware, so we're
    // back to the platform default ("auto-safe" on Android), which can
    // use the zero-copy path when the device supports it.
    // Capping the output size bounds how much every frame costs to
    // composite as a GPU texture underneath Flutter's UI layer — tried on
    // Android to work around low-fps/A-V-desync playback on the
    // Chromecast HD's weak Mali GPU. Gated to Android only: Windows
    // hardware has no such constraint, and forcing 720p there would only
    // needlessly cost picture quality.
    _controller = VideoController(
      _player,
      configuration: Platform.isAndroid
          ? const VideoControllerConfiguration(width: 1280, height: 720)
          : const VideoControllerConfiguration(),
    );
    _player.open(Media(widget.item.streamUrl));
    _scheduleHideControls();
    HardwareKeyboard.instance.addHandler(_onHardwareKey);

    if (widget.item.isLive) {
      _completedSubscription = _player.stream.completed.listen((completed) {
        if (completed) _reopen();
      });
      _bufferingSubscription = _player.stream.buffering.listen((buffering) {
        _stallTimer?.cancel();
        if (buffering) {
          _stallTimer = Timer(_stallTimeout, _reopen);
        }
      });
    }
  }

  void _reopen() {
    final lastReopen = _lastReopen;
    if (lastReopen != null && DateTime.now().difference(lastReopen) < _reopenCooldown) {
      return;
    }
    _lastReopen = DateTime.now();
    _player.open(Media(widget.item.streamUrl));
  }

  bool _onHardwareKey(KeyEvent event) {
    // Any remote button press (D-pad, back, select, ...) should bring the
    // top bar back; never consume the event, just observe it.
    _showControls();
    return false;
  }

  void _showControls() {
    _hideControlsTimer?.cancel();
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHideControls();
  }

  void _scheduleHideControls() {
    _hideControlsTimer = Timer(_controlsHideDelay, () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  @override
  void dispose() {
    _stallTimer?.cancel();
    _hideControlsTimer?.cancel();
    _completedSubscription?.cancel();
    _bufferingSubscription?.cancel();
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A live channel has no meaningful duration or seek position, so hide
    // the VOD-style seek bar rather than showing a progress indicator that
    // reflects nothing but however much has been buffered so far.
    final controlsTheme = MaterialDesktopVideoControlsThemeData(
      displaySeekBar: !widget.item.isLive,
    );
    final controlsThemeFullscreen = MaterialDesktopVideoControlsThemeData(
      displaySeekBar: !widget.item.isLive,
    );
    final mobileControlsTheme = MaterialVideoControlsThemeData(
      displaySeekBar: !widget.item.isLive,
    );
    final mobileControlsThemeFullscreen = MaterialVideoControlsThemeData(
      displaySeekBar: !widget.item.isLive,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _showControls,
        child: MaterialDesktopVideoControlsTheme(
          normal: controlsTheme,
          fullscreen: controlsThemeFullscreen,
          child: MaterialVideoControlsTheme(
            normal: mobileControlsTheme,
            fullscreen: mobileControlsThemeFullscreen,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Video(controller: _controller),
                StreamBuilder<bool>(
                  stream: _player.stream.buffering,
                  initialData: true,
                  builder: (context, snapshot) {
                    if (snapshot.data != true) return const SizedBox.shrink();
                    return const CircularProgressIndicator(color: Colors.white);
                  },
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: AnimatedOpacity(
                      opacity: _controlsVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black87, Colors.transparent],
                          ),
                        ),
                        child: SafeArea(
                          bottom: false,
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: () => Navigator.of(context).maybePop(),
                              ),
                              Expanded(
                                child: Text(
                                  widget.item.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 18),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ListenableBuilder(
                                listenable: FavoritesStore.instance,
                                builder: (context, _) {
                                  final isFavorite = FavoritesStore.instance
                                      .isFavorite(widget.item.streamUrl);
                                  return IconButton(
                                    icon: Icon(
                                      isFavorite ? Icons.star : Icons.star_border,
                                      color: isFavorite ? Colors.amber : Colors.white,
                                    ),
                                    onPressed: () =>
                                        FavoritesStore.instance.toggle(widget.item),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
