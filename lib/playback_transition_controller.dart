import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'sleep_timer_state.dart';

class PlaybackTransitionController {
  PlaybackTransitionController(this._player) {
    _positionSubscription = _player.positionStream.listen(_handlePosition);
    _discontinuitySubscription = _player.positionDiscontinuityStream.listen((
      event,
    ) {
      _pendingAutoAdvanceIndex =
          event.reason == PositionDiscontinuityReason.autoAdvance
          ? event.event.currentIndex
          : null;
    });
    _indexSubscription = _player.currentIndexStream.listen(_handleIndex);
    _playingSubscription = _player.playingStream.listen(_handlePlaying);
    _processingSubscription = _player.processingStateStream.listen(
      _handleProcessingState,
    );
  }

  final AudioPlayer _player;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<int?>? _indexSubscription;
  StreamSubscription<PositionDiscontinuity>? _discontinuitySubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<ProcessingState>? _processingSubscription;
  Timer? _fadeTimer;
  Timer? _sleepTimerTicker;
  DateTime? _fadeStartedAt;
  DateTime? _sleepLastTickAt;
  Duration _activeFadeDuration = Duration.zero;
  double _fadeStartingVolume = 1;
  int? _lastIndex;
  int? _pendingAutoAdvanceIndex;
  Duration? _lastPosition;
  Duration? _sleepRemaining;
  int _lastSleepDisplaySecond = -1;
  bool _hasSeenIndex = false;
  bool _enabled = false;
  bool _fadedOut = false;
  bool _sleepFadeStarted = false;
  bool _sleepFadeCompleted = false;
  Duration _fadeDuration = const Duration(seconds: 2);
  bool _volumeUpdatePending = false;
  double? _queuedVolume;
  final ValueNotifier<SleepTimerStatus?> sleepTimerState = ValueNotifier(null);

  void configure({required bool enabled, required Duration duration}) {
    _fadeDuration = duration;
    if (_enabled == enabled) return;
    _enabled = enabled;
    if (!enabled && sleepTimerState.value == null) _finishFade(1);
  }

  void startCountdown(Duration duration) {
    _cancelSleepTimer(restoreVolume: true);
    _sleepRemaining = duration;
    _sleepFadeStarted = false;
    _sleepFadeCompleted = false;
    _sleepLastTickAt = DateTime.now();
    _lastSleepDisplaySecond = -1;
    sleepTimerState.value = SleepTimerStatus.countdown(duration);
    _sleepTimerTicker = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _tickCountdown(),
    );
  }

  void startEndOfTrack() {
    _cancelSleepTimer(restoreVolume: true);
    _sleepFadeStarted = false;
    _sleepFadeCompleted = false;
    sleepTimerState.value = const SleepTimerStatus.endOfTrack();
    _updateEndOfTrackFade();
  }

  void cancelSleepTimer() {
    _cancelSleepTimer(restoreVolume: true);
  }

  void _cancelSleepTimer({required bool restoreVolume}) {
    _sleepTimerTicker?.cancel();
    _sleepTimerTicker = null;
    _sleepRemaining = null;
    _sleepLastTickAt = null;
    _sleepFadeStarted = false;
    _sleepFadeCompleted = false;
    sleepTimerState.value = null;
    if (restoreVolume) _finishFade(1);
  }

  void _tickCountdown() {
    final remaining = _sleepRemaining;
    if (remaining == null || sleepTimerState.value == null) return;

    final now = DateTime.now();
    final previousTick = _sleepLastTickAt ?? now;
    _sleepLastTickAt = now;
    if (_player.playing) {
      _sleepRemaining = remaining - now.difference(previousTick);
    }

    final updatedRemaining = _sleepRemaining!;
    if (_player.playing &&
        updatedRemaining <= const Duration(seconds: 30) &&
        !_sleepFadeStarted) {
      _sleepFadeStarted = true;
      _startFade(out: true, duration: updatedRemaining);
    }
    if (_player.playing && updatedRemaining <= Duration.zero) {
      unawaited(_completeSleepTimer());
      return;
    }

    final remainingSecond = updatedRemaining.inSeconds;
    if (remainingSecond != _lastSleepDisplaySecond) {
      _lastSleepDisplaySecond = remainingSecond;
      sleepTimerState.value = SleepTimerStatus.countdown(
        updatedRemaining < Duration.zero ? Duration.zero : updatedRemaining,
      );
    }
  }

  void _updateEndOfTrackFade() {
    if (sleepTimerState.value?.mode != SleepTimerMode.endOfTrack ||
        !_player.playing) {
      return;
    }
    final duration = _player.duration;
    if (duration == null) return;
    final remaining = duration - _player.position;
    if (remaining <= Duration.zero ||
        remaining > const Duration(seconds: 30) ||
        _sleepFadeStarted) {
      return;
    }
    _sleepFadeStarted = true;
    _startFade(out: true, duration: remaining);
  }

  Future<void> _completeSleepTimer() async {
    if (sleepTimerState.value == null) return;
    _sleepTimerTicker?.cancel();
    _sleepTimerTicker = null;
    _finishFade(0);
    try {
      await _player.pause();
    } catch (error) {
      debugPrint('No se pudo pausar al terminar el temporizador: $error');
    } finally {
      _cancelSleepTimer(restoreVolume: true);
    }
  }

  void _handlePosition(Duration position) {
    if (sleepTimerState.value?.mode == SleepTimerMode.endOfTrack &&
        _sleepFadeCompleted &&
        position < const Duration(milliseconds: 300) &&
        (_lastPosition ?? Duration.zero) > const Duration(seconds: 1)) {
      unawaited(_completeSleepTimer());
      return;
    }
    if (sleepTimerState.value?.mode == SleepTimerMode.endOfTrack) {
      _updateEndOfTrackFade();
    }
    if (sleepTimerState.value?.mode == SleepTimerMode.countdown &&
        _sleepRemaining != null &&
        _sleepRemaining! <= const Duration(seconds: 30) &&
        !_sleepFadeStarted &&
        _player.playing) {
      _sleepFadeStarted = true;
      _startFade(out: true, duration: _sleepRemaining!);
    }
    if (_enabled &&
        !_sleepFadeStarted &&
        _fadedOut &&
        position < const Duration(milliseconds: 300) &&
        (_lastPosition ?? Duration.zero) > const Duration(seconds: 1)) {
      _fadedOut = false;
      _startFade(out: false, duration: _fadeDuration);
    }
    _lastPosition = position;
    if (!_enabled ||
        !_player.playing ||
        _sleepFadeStarted ||
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
      _pendingAutoAdvanceIndex = null;
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
    if (sleepTimerState.value?.mode == SleepTimerMode.endOfTrack) {
      final reachedNaturalEnd =
          _sleepFadeCompleted || _pendingAutoAdvanceIndex == index;
      _pendingAutoAdvanceIndex = null;
      if (reachedNaturalEnd) {
        unawaited(_completeSleepTimer());
        return;
      }
      final wasSleepFadeStarted = _sleepFadeStarted;
      _sleepFadeStarted = false;
      _sleepFadeCompleted = false;
      if (wasSleepFadeStarted) _finishFade(1);
    } else if (sleepTimerState.value?.mode == SleepTimerMode.countdown &&
        _sleepFadeStarted) {
      _sleepFadeStarted = false;
      _sleepFadeCompleted = false;
      _finishFade(1);
    }
    _fadedOut = false;
    if (_enabled && _player.playing && !_sleepFadeStarted) {
      _startFade(out: false, duration: _fadeDuration);
    }
  }

  void _handlePlaying(bool playing) {
    if (!playing && sleepTimerState.value != null) {
      _sleepFadeStarted = false;
      _sleepFadeCompleted = false;
      _finishFade(1);
      return;
    }
    if (!playing) {
      _fadedOut = false;
      _finishFade(1);
    }
  }

  void _handleProcessingState(ProcessingState state) {
    if (state == ProcessingState.completed) {
      _fadedOut = false;
      if (sleepTimerState.value?.mode == SleepTimerMode.endOfTrack) {
        _cancelSleepTimer(restoreVolume: true);
      } else {
        _finishFade(1);
      }
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
        if (out && sleepTimerState.value != null) {
          _sleepFadeCompleted = true;
        }
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
    await _discontinuitySubscription?.cancel();
    await _indexSubscription?.cancel();
    await _playingSubscription?.cancel();
    await _processingSubscription?.cancel();
    _sleepTimerTicker?.cancel();
    await _player.setVolume(1);
    sleepTimerState.dispose();
  }
}
