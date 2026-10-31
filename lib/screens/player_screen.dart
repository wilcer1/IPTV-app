import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/media_item.dart';
import '../services/favorites_store.dart';
import '../services/watch_progress_store.dart';

class PlayerScreen extends StatefulWidget {
  final MediaItem item;

  /// The episodes of the show this one belongs to, in watching order. Lets
  /// the player offer "Next episode" and keep going when one finishes.
  final List<MediaItem>? queue;

  const PlayerScreen({super.key, required this.item, this.queue});

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

  static const _progressSaveInterval = Duration(seconds: 5);
  static const _resumeNoticeDuration = Duration(seconds: 8);

  // Offer "Next episode" once this little is left (credits territory).
  static const _nextEpisodeWindow = Duration(seconds: 40);

  late final Player _player;
  late final VideoController _controller;
  StreamSubscription<bool>? _completedSubscription;
  StreamSubscription<bool>? _bufferingSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  Timer? _stallTimer;
  Timer? _hideControlsTimer;
  Timer? _saveTimer;
  Timer? _resumeNoticeTimer;
  bool _controlsVisible = true;
  DateTime? _lastReopen;

  MediaItem? _next;
  Duration? _resumedFrom;
  // Until playback has actually reached the resume point, the player reports
  // position 0 — saving that would wipe out the very position we're resuming.
  bool _resumeApplied = true;
  bool _showResumeNotice = false;
  bool _nearEnd = false;
  bool _advancing = false;

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

    if (!widget.item.isLive) {
      _next = _resolveNext();
      final saved = WatchProgressStore.instance.entryFor(widget.item.id);
      if (saved != null &&
          !saved.completed &&
          saved.positionMs >= WatchProgressStore.minTrackedPosition.inMilliseconds) {
        _resumedFrom = Duration(milliseconds: saved.positionMs);
        _resumeApplied = false;
        _showResumeNotice = true;
        _resumeNoticeTimer = Timer(_resumeNoticeDuration, () {
          if (mounted) setState(() => _showResumeNotice = false);
        });
      }
    }

    _player.open(Media(widget.item.streamUrl, start: _resumedFrom));
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
    } else {
      _positionSubscription = _player.stream.position.listen(_onPosition);
      _saveTimer = Timer.periodic(_progressSaveInterval, (_) => _saveProgress());
      _completedSubscription = _player.stream.completed.listen((completed) {
        if (completed) _onFinished();
      });
    }
  }

  MediaItem? _resolveNext() {
    final queue = widget.queue;
    if (queue == null) return null;
    final index = queue.indexWhere((e) => e.id == widget.item.id);
    return (index >= 0 && index + 1 < queue.length) ? queue[index + 1] : null;
  }

  void _onPosition(Duration position) {
    final resumedFrom = _resumedFrom;
    if (!_resumeApplied &&
        resumedFrom != null &&
        position >= resumedFrom - const Duration(seconds: 3)) {
      _resumeApplied = true;
    }

    final duration = _player.state.duration;
    final nearEnd = _next != null &&
        duration > const Duration(minutes: 5) &&
        duration - position <= _nextEpisodeWindow;
    if (nearEnd != _nearEnd && mounted) setState(() => _nearEnd = nearEnd);
  }

  void _saveProgress() {
    if (widget.item.isLive || !_resumeApplied) return;
    final duration = _player.state.duration;
    if (duration <= Duration.zero) return;
    WatchProgressStore.instance.record(
      widget.item,
      position: _player.state.position,
      duration: duration,
      next: _next,
    );
  }

  void _onFinished() {
    final duration = _player.state.duration;
    if (_advancing || duration < WatchProgressStore.minTrackedDuration) return;
    _advancing = true;

    WatchProgressStore.instance.record(
      widget.item,
      position: duration,
      duration: duration,
      next: _next,
    );

    if (_next != null) {
      _playNext();
    } else if (mounted) {
      // Nothing follows (a movie, or a show's last episode): back to browsing.
      Navigator.of(context).maybePop();
    }
  }

  void _playNext() {
    final next = _next;
    if (next == null || !mounted) return;
    _advancing = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => PlayerScreen(item: next, queue: widget.queue)),
    );
  }

  void _startOver() {
    _player.seek(Duration.zero);
    WatchProgressStore.instance.remove(widget.item.id);
    _resumeApplied = true;
    setState(() => _showResumeNotice = false);
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
    // Must happen before the player is disposed: its state is gone after.
    _saveProgress();
    WatchProgressStore.instance.flush();

    _stallTimer?.cancel();
    _hideControlsTimer?.cancel();
    _saveTimer?.cancel();
    _resumeNoticeTimer?.cancel();
    _completedSubscription?.cancel();
    _bufferingSubscription?.cancel();
    _positionSubscription?.cancel();
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _player.dispose();
    super.dispose();
  }

  String _formatTime(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
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

    final title = widget.item.seriesTitle != null
        ? '${widget.item.seriesTitle}${widget.item.episodeLabel != null ? ' · ${widget.item.episodeLabel}' : ''}'
        : widget.item.name;

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
                if (_showResumeNotice && _resumedFrom != null)
                  Positioned(
                    left: 16,
                    bottom: 110,
                    child: Material(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 14, right: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Resumed at ${_formatTime(_resumedFrom!)}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            TextButton(
                              onPressed: _startOver,
                              child: const Text('Start over'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_nearEnd && _next != null)
                  Positioned(
                    right: 16,
                    bottom: 110,
                    child: FilledButton.icon(
                      onPressed: _playNext,
                      icon: const Icon(Icons.skip_next),
                      label: const Text('Next episode'),
                    ),
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
                                  title,
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
