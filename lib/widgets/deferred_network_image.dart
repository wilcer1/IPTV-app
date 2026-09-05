import 'dart:async';

import 'package:flutter/material.dart';

/// Bounds how many [DeferredNetworkImage]s may be decoding at once,
/// app-wide. Extra requests wait their turn instead of firing off a
/// network fetch + decode immediately.
///
/// Rapidly traversing a long list with a TV remote's D-pad (holding
/// "down" for key-repeat) creates many new list tiles per second — far
/// more bursty than a touch fling, and not reliably caught by
/// [Scrollable.recommendDeferredLoadingForContext], which keys off scroll
/// *velocity* and barely registers the small per-row `ensureVisible`
/// animations D-pad focus traversal uses. On a device already this close
/// to its memory ceiling (confirmed via `adb shell top`: ~76MB free out of
/// 1.4GB, zram swap at 96% capacity even at idle on a real Chromecast HD),
/// that burst of concurrent decodes is enough to trigger a multi-second
/// main-thread stall and ANR. Capping concurrency bounds the burst
/// regardless of what's driving the scroll.
class _ImageLoadLimiter {
  static const int maxConcurrent = 3;
  static int _active = 0;
  static final List<Completer<void>> _waiting = [];

  /// Returns null if a slot was acquired synchronously, otherwise a
  /// [Completer] that completes once one frees up.
  static Completer<void>? tryAcquireOrEnqueue() {
    if (_active < maxConcurrent) {
      _active++;
      return null;
    }
    final completer = Completer<void>();
    _waiting.add(completer);
    return completer;
  }

  static void release() {
    _active--;
    if (_waiting.isNotEmpty) {
      _active++;
      _waiting.removeAt(0).complete();
    }
  }

  static void cancelWaiting(Completer<void> completer) {
    _waiting.remove(completer);
  }
}

class DeferredNetworkImage extends StatefulWidget {
  final String url;
  final Widget placeholder;
  final BoxFit fit;
  final double? width;
  final int? cacheWidth;
  final int? cacheHeight;

  const DeferredNetworkImage({
    super.key,
    required this.url,
    required this.placeholder,
    this.fit = BoxFit.cover,
    this.width,
    this.cacheWidth,
    this.cacheHeight,
  });

  @override
  State<DeferredNetworkImage> createState() => _DeferredNetworkImageState();
}

class _DeferredNetworkImageState extends State<DeferredNetworkImage> {
  bool _acquired = false;
  Completer<void>? _waitingCompleter;
  bool _released = false;

  @override
  void initState() {
    super.initState();
    final waiting = _ImageLoadLimiter.tryAcquireOrEnqueue();
    if (waiting == null) {
      _acquired = true;
    } else {
      _waitingCompleter = waiting;
      waiting.future.then((_) {
        _waitingCompleter = null;
        if (!mounted) {
          _release();
          return;
        }
        setState(() => _acquired = true);
      });
    }
  }

  void _release() {
    if (_released) return;
    _released = true;
    if (_acquired) {
      _ImageLoadLimiter.release();
    } else if (_waitingCompleter != null) {
      _ImageLoadLimiter.cancelWaiting(_waitingCompleter!);
    }
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_acquired) return widget.placeholder;
    return Image.network(
      widget.url,
      fit: widget.fit,
      width: widget.width,
      cacheWidth: widget.cacheWidth,
      cacheHeight: widget.cacheHeight,
      // Free the slot for the next queued image as soon as this one has
      // decoded its first frame — holding it any longer than that
      // wouldn't bound anything further.
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame != null) _release();
        return child;
      },
      errorBuilder: (_, _, _) {
        _release();
        return widget.placeholder;
      },
    );
  }
}
