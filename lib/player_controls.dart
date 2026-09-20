import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'widgets.dart';

class PlayerControls extends StatefulWidget {
  const PlayerControls({
    super.key,
    required this.player,
    required this.fullscreen,
    required this.onFullscreen,
    required this.onPrevious,
    required this.onNext,
    required this.title,
    required this.onTogglePlayback,
    this.swipeEnabled = false,
  });

  final Player player;
  final bool fullscreen;
  final VoidCallback onFullscreen;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final String title;
  final VoidCallback onTogglePlayback;
  final bool swipeEnabled;

  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<PlayerControls> {
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _hideTimer;
  bool _visible = true;
  double? _seekValue;
  Offset? _dragStart;
  double _dragDistance = 0;

  @override
  void initState() {
    super.initState();
    for (final stream in [
      widget.player.stream.position,
      widget.player.stream.duration,
      widget.player.stream.playing,
      widget.player.stream.buffering,
      widget.player.stream.volume,
    ]) {
      _subscriptions.add(
        stream.listen((_) {
          if (mounted) {
            setState(() {});
          }
        }),
      );
    }
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && widget.player.state.playing && _seekValue == null) {
        setState(() => _visible = false);
      }
    });
  }

  void _show() {
    if (!_visible) {
      setState(() => _visible = true);
    }
    _scheduleHide();
  }

  void _toggle() {
    setState(() => _visible = !_visible);
    if (_visible) {
      _scheduleHide();
    }
  }

  void _finishSwipe(DragEndDetails details) {
    final start = _dragStart;
    _dragStart = null;
    if (start == null) {
      return;
    }
    final height = context.size?.height ?? 0;
    final velocity = details.primaryVelocity ?? 0;
    if (start.dy > height - 72 ||
        (_dragDistance.abs() < 70 &&
            !(velocity.abs() > 650 && _dragDistance.abs() > 25))) {
      return;
    }
    if (_dragDistance < 0) {
      widget.onNext?.call();
    } else {
      widget.onPrevious?.call();
    }
    _show();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.player.state;
    final duration = state.duration.inMilliseconds / 1000;
    final position = state.position.inMilliseconds / 1000;
    final visible = _visible || !state.playing;
    return MouseRegion(
      onHover: (_) => _show(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        onDoubleTap: () {
          widget.onTogglePlayback();
          _show();
        },
        onVerticalDragStart: widget.swipeEnabled
            ? (details) {
                _dragStart = details.localPosition;
                _dragDistance = 0;
              }
            : null,
        onVerticalDragUpdate: widget.swipeEnabled
            ? (details) => _dragDistance += details.primaryDelta ?? 0
            : null,
        onVerticalDragEnd: widget.swipeEnabled ? _finishSwipe : null,
        onVerticalDragCancel: widget.swipeEnabled
            ? () => _dragStart = null
            : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (state.buffering)
              const Center(child: CircularProgressIndicator()),
            IgnorePointer(
              ignoring: !visible,
              child: AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x66000000),
                            Colors.transparent,
                            Color(0xCC000000),
                          ],
                          stops: [0, .45, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 12,
                      right: 12,
                      child: Row(
                        children: [
                          if (widget.fullscreen)
                            IconButton(
                              tooltip: '退出全屏',
                              onPressed: widget.onFullscreen,
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                          Expanded(
                            child: Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!state.buffering)
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: '上一集',
                              onPressed: widget.onPrevious,
                              icon: const Icon(Icons.skip_previous_rounded),
                            ),
                            const SizedBox(width: 12),
                            IconButton.filledTonal(
                              tooltip: state.playing ? '暂停' : '播放',
                              iconSize: 38,
                              onPressed: () {
                                widget.onTogglePlayback();
                                _show();
                              },
                              icon: Icon(
                                state.playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              tooltip: '下一集',
                              onPressed: widget.onNext,
                              icon: const Icon(Icons.skip_next_rounded),
                            ),
                          ],
                        ),
                      ),
                    Positioned(
                      left: 12,
                      right: 4,
                      bottom: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(
                              context,
                            ).copyWith(trackHeight: 2),
                            child: Slider(
                              value: (_seekValue ?? position).clamp(
                                0,
                                duration > 0 ? duration : 1,
                              ),
                              max: duration > 0 ? duration : 1,
                              onChanged: duration <= 0
                                  ? null
                                  : (value) {
                                      _hideTimer?.cancel();
                                      setState(() => _seekValue = value);
                                    },
                              onChangeEnd: (value) {
                                widget.player.seek(
                                  Duration(
                                    milliseconds: (value * 1000).round(),
                                  ),
                                );
                                setState(() => _seekValue = null);
                                _show();
                              },
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '${formatPosition(_seekValue ?? position)} / ${formatPosition(duration)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const Spacer(),
                              if (!widget.swipeEnabled)
                                IconButton(
                                  tooltip: state.volume == 0 ? '取消静音' : '静音',
                                  onPressed: () => widget.player.setVolume(
                                    state.volume == 0 ? 100 : 0,
                                  ),
                                  icon: Icon(
                                    state.volume == 0
                                        ? Icons.volume_off_rounded
                                        : Icons.volume_up_rounded,
                                  ),
                                ),
                              IconButton(
                                tooltip: widget.fullscreen ? '退出全屏' : '旋转与全屏',
                                onPressed: widget.onFullscreen,
                                icon: Icon(
                                  widget.fullscreen
                                      ? Icons.fullscreen_exit_rounded
                                      : Icons.fullscreen_rounded,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
