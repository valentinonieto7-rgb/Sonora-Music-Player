import 'dart:ui' show ImageFilter;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';

import 'artwork_widgets.dart';
import 'audio_file_info.dart';
import 'marquee_text.dart';
import 'ui_helpers.dart';
import 'format_duration.dart';
import 'sleep_timer_state.dart';

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({
    required this.currentSong,
    required this.audioQuery,
    required this.audioPlayer,
    required this.sleepTimerState,
    required this.backgroundStyle,
    required this.accentColor,
    required this.isShuffleEnabled,
    required this.isRepeatEnabled,
    required this.onPrevious,
    required this.onNext,
    required this.onStartSleepTimer,
    required this.onCancelSleepTimer,
    required this.onAddToPlaylist,
    required this.onOpenQueue,
    required this.onShuffleChanged,
    required this.onRepeatChanged,
    required this.isFavorite,
    required this.onFavoriteChanged,
    super.key,
  });

  final ValueListenable<SongModel?> currentSong;
  final OnAudioQuery audioQuery;
  final AudioPlayer audioPlayer;
  final ValueListenable<SleepTimerStatus?> sleepTimerState;
  final String backgroundStyle;
  final Color accentColor;
  final bool isShuffleEnabled;
  final bool isRepeatEnabled;
  final Future<void> Function() onPrevious;
  final Future<void> Function() onNext;
  final ValueChanged<Duration?> onStartSleepTimer;
  final VoidCallback onCancelSleepTimer;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onOpenQueue;
  final ValueChanged<bool> onShuffleChanged;
  final Future<void> Function(bool enabled) onRepeatChanged;
  final bool Function(int songId) isFavorite;
  final VoidCallback onFavoriteChanged;

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  late bool _isShuffleEnabled = widget.isShuffleEnabled;
  late bool _isRepeatEnabled = widget.isRepeatEnabled;
  late bool _isFavorite = widget.isFavorite(widget.currentSong.value?.id ?? -1);
  int? _favoriteSongId;
  double _horizontalDragDistance = 0;

  @override
  void initState() {
    super.initState();
    _favoriteSongId = widget.currentSong.value?.id;
    widget.currentSong.addListener(_syncFavoriteForCurrentSong);
  }

  @override
  void didUpdateWidget(covariant NowPlayingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentSong != widget.currentSong) {
      oldWidget.currentSong.removeListener(_syncFavoriteForCurrentSong);
      widget.currentSong.addListener(_syncFavoriteForCurrentSong);
      _syncFavoriteForCurrentSong();
    }
  }

  @override
  void dispose() {
    widget.currentSong.removeListener(_syncFavoriteForCurrentSong);
    super.dispose();
  }

  void _syncFavoriteForCurrentSong() {
    final song = widget.currentSong.value;
    if (song == null || song.id == _favoriteSongId) return;
    setState(() {
      _favoriteSongId = song.id;
      _isFavorite = widget.isFavorite(song.id);
    });
  }

  Future<void> _showSleepTimerSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: ValueListenableBuilder<SleepTimerStatus?>(
            valueListenable: widget.sleepTimerState,
            builder: (context, timerStatus, _) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(
                  'Temporizador de apagado',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (timerStatus != null) ...[
                  const SizedBox(height: 8),
                  Text('Activo: ${timerStatus.label}'),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.timer_off_outlined),
                    title: const Text('Cancelar temporizador'),
                    onTap: () {
                      widget.onCancelSleepTimer();
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(),
                ],
                for (final minutes in [15, 30, 45, 60])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_rounded),
                    title: Text('En $minutes minutos'),
                    onTap: () {
                      widget.onStartSleepTimer(Duration(minutes: minutes));
                      Navigator.pop(context);
                    },
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.queue_music_rounded),
                  title: const Text('Al terminar la canción actual'),
                  subtitle: const Text(
                    'Bajará el volumen durante 30 segundos',
                  ),
                  enabled: widget.audioPlayer.duration != null,
                  onTap: widget.audioPlayer.duration == null
                      ? null
                      : () {
                          widget.onStartSleepTimer(null);
                          Navigator.pop(context);
                        },
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _trackSwipeTarget(Widget child) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _horizontalDragDistance = 0,
      onHorizontalDragUpdate: (details) {
        _horizontalDragDistance += details.delta.dx;
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 250 && _horizontalDragDistance.abs() < 56) {
          _horizontalDragDistance = 0;
          return;
        }

        final direction = velocity.abs() >= 250
            ? velocity
            : _horizontalDragDistance;
        _horizontalDragDistance = 0;
        if (direction < 0) {
          widget.onNext();
        } else {
          widget.onPrevious();
        }
      },
      child: child,
    );
  }

  Widget _buildBackground(BuildContext context) {
    final style = widget.backgroundStyle;
    final blurAmount = style == 'blurred' ? 48.0 : 38.0;
    final artworkOpacity = style == 'blurred'
        ? 0.42
        : style == 'gradient'
        ? 0.5
        : 0.18;
    final accentHue = HSLColor.fromColor(widget.accentColor);
    final alternateColor = accentHue
        .withHue((accentHue.hue + 42) % 360)
        .toColor();

    return Stack(
      fit: StackFit.expand,
      children: [
        if (style == 'accent')
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.65, -0.75),
                radius: 1.15,
                colors: [
                  widget.accentColor.withValues(alpha: 0.72),
                  widget.accentColor.withValues(alpha: 0.3),
                  Colors.black,
                ],
                stops: const [0, 0.48, 1],
              ),
            ),
          ),
        ValueListenableBuilder<SongModel?>(
          valueListenable: widget.currentSong,
          builder: (context, song, _) {
            if (song == null) return const SizedBox.shrink();
            return IgnorePointer(
              child: ClipRect(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: blurAmount,
                    sigmaY: blurAmount,
                  ),
                  child: Opacity(
                    opacity: artworkOpacity,
                    child: CachedArtwork(
                      controller: widget.audioQuery,
                      id: song.id,
                      width: MediaQuery.sizeOf(context).width,
                      height: MediaQuery.sizeOf(context).height,
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (style == 'gradient')
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.accentColor.withValues(alpha: 0.62),
                  alternateColor.withValues(alpha: 0.48),
                  Colors.black.withValues(alpha: 0.8),
                ],
                stops: const [0, 0.52, 1],
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: style == 'blurred'
                  ? const [
                      Color(0xB8000000),
                      Color(0xD9000000),
                      Color(0xF5000000),
                    ]
                  : [
                      Colors.black.withValues(
                        alpha: style == 'accent' ? 0.36 : 0.2,
                      ),
                      Colors.black.withValues(alpha: 0.56),
                      const Color(0xF5000000),
                    ],
              stops: const [0, 0.52, 1],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'REPRODUCIENDO AHORA',
          style: TextStyle(fontSize: 13, letterSpacing: 1.2),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Cola de reproducción',
            onPressed: widget.onOpenQueue,
            icon: const Icon(Icons.queue_music_rounded),
          ),
          ValueListenableBuilder<SleepTimerStatus?>(
            valueListenable: widget.sleepTimerState,
            builder: (context, status, _) => IconButton(
              tooltip: status == null
                  ? 'Temporizador de apagado'
                  : 'Temporizador activo: ${status.label}',
              onPressed: _showSleepTimerSheet,
              icon: Icon(
                status == null ? Icons.timer_outlined : Icons.timer_rounded,
                color: status == null ? Colors.white : widget.accentColor,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(context),
          SafeArea(
            top: false,
            child: ValueListenableBuilder<SongModel?>(
              valueListenable: widget.currentSong,
              builder: (context, song, _) {
                if (song == null) {
                  return const Center(
                    child: Text('No hay canción seleccionada'),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final artworkSize = min(
                      constraints.maxWidth,
                      constraints.maxHeight * 0.48,
                    ).toDouble();

                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _trackSwipeTarget(
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 260),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  transitionBuilder: (child, animation) =>
                                      FadeTransition(
                                        opacity: animation,
                                        child: ScaleTransition(
                                          scale: Tween<double>(
                                            begin: 0.96,
                                            end: 1,
                                          ).animate(animation),
                                          child: child,
                                        ),
                                      ),
                                  child: ConstrainedBox(
                                    key: ValueKey(song.id),
                                    constraints: BoxConstraints(
                                      maxWidth: artworkSize,
                                      maxHeight: artworkSize,
                                    ),
                                    child: AspectRatio(
                                      aspectRatio: 1,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            22,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withValues(alpha: 0.16),
                                              blurRadius: 34,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            22,
                                          ),
                                          child: CachedArtwork(
                                            controller: widget.audioQuery,
                                            id: song.id,
                                            width: artworkSize,
                                            height: artworkSize,
                                            borderRadius: BorderRadius.circular(
                                              22,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),
                              _trackSwipeTarget(
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          MarqueeText(
                                            song.title,
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            song.artist ??
                                                'Artista desconocido',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: secondaryTextColor(
                                                context,
                                              ),
                                            ),
                                          ),
                                          if (song.album?.trim().isNotEmpty ==
                                              true)
                                            Text(
                                              song.album!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: secondaryTextColor(
                                                  context,
                                                  0.38,
                                                ),
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: _isFavorite
                                          ? 'Quitar de favoritos'
                                          : 'Añadir a favoritos',
                                      onPressed: () {
                                        widget.onFavoriteChanged();
                                        setState(
                                          () => _isFavorite = !_isFavorite,
                                        );
                                      },
                                      icon: Icon(
                                        _isFavorite
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        color: _isFavorite
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                            : secondaryTextColor(context, 0.7),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Agregar a playlist',
                                      onPressed: widget.onAddToPlaylist,
                                      icon: const Icon(
                                            Icons.playlist_add_rounded,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              _AudioDetails(song: song),
                              const SizedBox(height: 10),
                              _buildProgress(),
                              const SizedBox(height: 10),
                              _buildControls(),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    return StreamBuilder<Duration?>(
      stream: widget.audioPlayer.durationStream,
      builder: (context, durationSnapshot) {
        final duration =
            durationSnapshot.data ??
            widget.audioPlayer.duration ??
            Duration.zero;
        final max = duration.inMilliseconds.toDouble();

        return StreamBuilder<Duration>(
          stream: widget.audioPlayer.positionStream,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final value = max == 0
                ? 0.0
                : position.inMilliseconds.toDouble().clamp(0.0, max);

            return Column(
              children: [
                Slider(
                  value: value,
                  max: max > 0 ? max : 1,
                  onChanged: max <= 0
                      ? null
                      : (newValue) => widget.audioPlayer.seek(
                          Duration(milliseconds: newValue.round()),
                        ),
                  activeColor: Theme.of(context).colorScheme.primary,
                  inactiveColor: secondaryTextColor(context, 0.24),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatDuration(position),
                        style: TextStyle(
                          color: secondaryTextColor(context),
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        formatDuration(duration),
                        style: TextStyle(
                          color: secondaryTextColor(context),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: 'Aleatorio',
          onPressed: () {
            setState(() {
              _isShuffleEnabled = !_isShuffleEnabled;
            });
            widget.onShuffleChanged(_isShuffleEnabled);
          },
          icon: Icon(
            Icons.shuffle_rounded,
            color: _isShuffleEnabled
                ? Theme.of(context).colorScheme.primary
                : secondaryTextColor(context, 0.54),
          ),
        ),
        IconButton(
          tooltip: 'Anterior',
          onPressed: widget.onPrevious,
          icon: const Icon(Icons.skip_previous_rounded, size: 36),
        ),
        StreamBuilder<PlayerState>(
          stream: widget.audioPlayer.playerStateStream,
          builder: (context, snapshot) {
            final isPlaying =
                snapshot.data?.playing ?? widget.audioPlayer.playing;
            return FilledButton(
              onPressed: () => isPlaying
                  ? widget.audioPlayer.pause()
                  : widget.audioPlayer.play(),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(18),
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 34,
              ),
            );
          },
        ),
        IconButton(
          tooltip: 'Siguiente',
          onPressed: widget.onNext,
          icon: const Icon(Icons.skip_next_rounded, size: 36),
        ),
        IconButton(
          tooltip: 'Repetir canción',
          onPressed: () async {
            final enabled = !_isRepeatEnabled;
            await widget.onRepeatChanged(enabled);
            if (mounted) {
              setState(() {
                _isRepeatEnabled = enabled;
              });
            }
          },
          icon: Icon(
            Icons.repeat_one_rounded,
            color: _isRepeatEnabled
                ? Theme.of(context).colorScheme.primary
                : secondaryTextColor(context, 0.54),
          ),
        ),
      ],
    );
  }
}

class _AudioDetails extends StatefulWidget {
  const _AudioDetails({required this.song});

  final SongModel song;

  @override
  State<_AudioDetails> createState() => _AudioDetailsState();
}

class _AudioDetailsState extends State<_AudioDetails> {
  late Future<AudioFileInfo> _infoFuture;
  bool _loggedError = false;

  @override
  void initState() {
    super.initState();
    _infoFuture = _loadInfo();
  }

  @override
  void didUpdateWidget(covariant _AudioDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.data != widget.song.data) {
      _loggedError = false;
      _infoFuture = _loadInfo();
    }
  }

  Future<AudioFileInfo> _loadInfo() =>
      readAudioFileInfo(widget.song.data, widget.song.duration);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AudioFileInfo>(
      future: _infoFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (!_loggedError) {
            _loggedError = true;
            debugPrint(
              'No se pudieron leer los datos técnicos de ${widget.song.data}: '
              '${snapshot.error}',
            );
          }
          return const SizedBox.shrink();
        }
        if (!snapshot.hasData) return const SizedBox(height: 18);
        return Text(
          snapshot.data!.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: secondaryTextColor(context, 0.72),
            fontSize: 11,
            letterSpacing: 0.25,
          ),
        );
      },
    );
  }
}
