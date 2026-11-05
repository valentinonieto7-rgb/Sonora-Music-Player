import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class PlaybackTransitionController {
  PlaybackTransitionController(this._player) {
    _positionSubscription = _player.positionStream.listen(_handlePosition);
    _indexSubscription = _player.currentIndexStream.listen(_handleIndex);
    _playingSubscription = _player.playingStream.listen(_handlePlaying);
    _processingSubscription = _player.processingStateStream.listen(
      _handleProcessingState,
    );
  }

  final AudioPlayer _player;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<int?>? _indexSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<ProcessingState>? _processingSubscription;
  Timer? _fadeTimer;
  DateTime? _fadeStartedAt;
  Duration _activeFadeDuration = Duration.zero;
  double _fadeStartingVolume = 1;
  int? _lastIndex;
  Duration? _lastPosition;
  bool _hasSeenIndex = false;
  bool _enabled = false;
  bool _fadedOut = false;
  Duration _fadeDuration = const Duration(seconds: 2);
  bool _volumeUpdatePending = false;
  double? _queuedVolume;

  void configure({required bool enabled, required Duration duration}) {
    _fadeDuration = duration;
    if (_enabled == enabled) return;
    _enabled = enabled;
    if (!enabled) _finishFade(1);
  }

  void _handlePosition(Duration position) {
    if (_enabled &&
        _fadedOut &&
        position < const Duration(milliseconds: 300) &&
        (_lastPosition ?? Duration.zero) > const Duration(seconds: 1)) {
      _fadedOut = false;
      _startFade(out: false, duration: _fadeDuration);
    }
    _lastPosition = position;
    if (!_enabled ||
        !_player.playing ||
        _fadedOut ||
        _fadeTimer?.isActive == true) {
      return;
    }

    final trackDuration = _player.duration;
    if (trackDuration == null || trackDuration <= position) return;
    final remaining = trackDuration - position;
    if (remaining <= _fadeDuration) {
      _startFade(out: true, duration: remaining);
    }
  }

  void _handleIndex(int? index) {
    if (index == null) {
      _hasSeenIndex = false;
      _lastIndex = null;
      _lastPosition = null;
      return;
    }
    if (!_hasSeenIndex) {
      _hasSeenIndex = true;
      _lastIndex = index;
      return;
    }
    if (_lastIndex == index) return;
    _lastIndex = index;
    _fadedOut = false;
    if (_enabled && _player.playing) {
      _startFade(out: false, duration: _fadeDuration);
    }
  }

  void _handlePlaying(bool playing) {
    if (!playing) {
      _fadedOut = false;
      _finishFade(1);
    }
  }

  void _handleProcessingState(ProcessingState state) {
    if (state == ProcessingState.completed) {
      _fadedOut = false;
      _finishFade(1);
    }
  }

  void _startFade({required bool out, required Duration duration}) {
    if (duration <= Duration.zero) return;
    _fadeTimer?.cancel();
    _fadeStartedAt = DateTime.now();
    _activeFadeDuration = duration;
    _fadeStartingVolume = out ? _player.volume : 0;
    if (!out) _setVolume(0);
    _fadeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      final elapsed = DateTime.now().difference(_fadeStartedAt!);
      final progress =
          (elapsed.inMicroseconds / _activeFadeDuration.inMicroseconds).clamp(
            0.0,
            1.0,
          );
      _setVolume(out ? _fadeStartingVolume * (1 - progress) : progress);
      if (progress >= 1) {
        timer.cancel();
        _fadeTimer = null;
        _fadeStartedAt = null;
        if (out) _fadedOut = true;
      }
    });
  }

  void _finishFade(double volume) {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _fadeStartedAt = null;
    _fadedOut = false;
    _setVolume(volume);
  }

  void _setVolume(double volume) {
    if (_volumeUpdatePending) {
      _queuedVolume = volume;
      return;
    }
    if ((_player.volume - volume).abs() < 0.02) return;
    _volumeUpdatePending = true;
    unawaited(_applyVolume(volume));
  }

  Future<void> _applyVolume(double volume) async {
    try {
      await _player.setVolume(volume);
    } catch (error) {
      debugPrint('No se pudo ajustar el volumen gradualmente: $error');
    } finally {
      _volumeUpdatePending = false;
      final queuedVolume = _queuedVolume;
      _queuedVolume = null;
      if (queuedVolume != null &&
          (_player.volume - queuedVolume).abs() >= 0.02) {
        _setVolume(queuedVolume);
      }
    }
  }

  Future<void> dispose() async {
    _fadeTimer?.cancel();
    await _positionSubscription?.cancel();
    await _indexSubscription?.cancel();
    await _playingSubscription?.cancel();
    await _processingSubscription?.cancel();
    await _player.setVolume(1);
  }
}
