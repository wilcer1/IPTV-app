import 'dart:async';

import 'package:flutter/material.dart';
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

  late final Player _player;
  late final VideoController _controller;
  StreamSubscription<bool>? _completedSubscription;
  StreamSubscription<bool>? _bufferingSubscription;
  Timer? _stallTimer;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _player.open(Media(widget.item.streamUrl));

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
    _player.open(Media(widget.item.streamUrl));
  }

  @override
  void dispose() {
    _stallTimer?.cancel();
    _completedSubscription?.cancel();
    _bufferingSubscription?.cancel();
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
      appBar: AppBar(
        title: Text(widget.item.name),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          ListenableBuilder(
            listenable: FavoritesStore.instance,
            builder: (context, _) {
              final isFavorite =
                  FavoritesStore.instance.isFavorite(widget.item.streamUrl);
              return IconButton(
                icon: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  color: isFavorite ? Colors.amber : Colors.white,
                ),
                onPressed: () => FavoritesStore.instance.toggle(widget.item),
              );
            },
          ),
        ],
      ),
      body: Center(
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
