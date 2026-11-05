import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'artwork_widgets.dart';
import 'audio_file_info.dart';
import 'equalizer_presets.dart';
import 'equalizer_state.dart';
import 'music_settings_page.dart';
import 'now_playing_page.dart';
import 'playback_queue.dart';
import 'playback_session.dart';
import 'playlist_library_page.dart';
import 'playlist_model.dart';
import 'playback_transition_controller.dart';
import 'ui_helpers.dart';
import 'format_duration.dart';

class MusicHomePage extends StatefulWidget {
  const MusicHomePage({
    required this.amoledMode,
    required this.themeStyle,
    required this.accentColor,
    required this.refreshRate,
    required this.coverStyle,
    required this.playerBackgroundStyle,
    required this.equalizerEnabled,
    required this.equalizerPreset,
    required this.equalizerBandGains,
    required this.smoothTransitionsEnabled,
    required this.transitionDurationSeconds,
    required this.preloadQueue,
    required this.skipShortTracks,
    required this.onThemeStyleChanged,
    required this.onAccentColorChanged,
    required this.onRefreshRateChanged,
    required this.onCoverStyleChanged,
    required this.onPlayerBackgroundStyleChanged,
    required this.onEqualizerEnabledChanged,
    required this.onEqualizerPresetChanged,
    required this.onEqualizerBandGainsChanged,
    required this.onSmoothTransitionsEnabledChanged,
    required this.onTransitionDurationChanged,
    required this.onPreloadQueueChanged,
    required this.onSkipShortTracksChanged,
    super.key,
  });

  final bool amoledMode;
  final String themeStyle;
  final Color accentColor;
  final String refreshRate;
  final String coverStyle;
  final String playerBackgroundStyle;
  final bool equalizerEnabled;
  final String equalizerPreset;
  final List<double> equalizerBandGains;
  final bool smoothTransitionsEnabled;
  final int transitionDurationSeconds;
  final bool preloadQueue;
  final bool skipShortTracks;
  final Future<void> Function(String style) onThemeStyleChanged;
  final Future<void> Function(Color color) onAccentColorChanged;
  final Future<void> Function(String value) onRefreshRateChanged;
  final Future<void> Function(String style) onCoverStyleChanged;
  final Future<void> Function(String style) onPlayerBackgroundStyleChanged;
  final Future<void> Function(bool enabled) onEqualizerEnabledChanged;
  final Future<void> Function(String preset) onEqualizerPresetChanged;
  final Future<void> Function(List<double> gains) onEqualizerBandGainsChanged;
  final Future<void> Function(bool enabled) onSmoothTransitionsEnabledChanged;
  final Future<void> Function(int seconds) onTransitionDurationChanged;
  final Future<void> Function(bool enabled) onPreloadQueueChanged;
  final Future<void> Function(bool enabled) onSkipShortTracksChanged;

  @override
  State<MusicHomePage> createState() => _MusicHomePageState();
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: 88,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 25),
                  const SizedBox(height: 7),
                  Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MusicHomePageState extends State<MusicHomePage>
    with WidgetsBindingObserver {
  Color get _accent => widget.accentColor;
  static const _folderPreferenceKey = 'music_folder_path';
  static const _favoritesPreferenceKey = 'favorite_song_ids';
  static const _historyPreferenceKey = 'listening_history';
  static const _playCountsPreferenceKey = 'song_play_counts';
  static const _playlistsPreferenceKey = 'custom_playlists';
  static const _playbackSessionPreferenceKey = 'playback_session';
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AndroidEqualizer _equalizer = AndroidEqualizer();
  late final AudioPlayer _audioPlayer = AudioPlayer(
    audioPipeline: AudioPipeline(androidAudioEffects: [_equalizer]),
  );
  final ValueNotifier<EqualizerState> _equalizerStateNotifier = ValueNotifier(
    const EqualizerState(),
  );
  final TextEditingController _searchController = TextEditingController();
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  final ValueNotifier<SongModel?> _currentSongNotifier = ValueNotifier(null);

  List<SongModel> _songs = [];
  List<SongModel> _playbackQueue = [];
  List<Playlist> _playlists = [];
  String? _activePlaylistId;
  final Set<int> _favoriteSongIds = {};
  List<int> _recentSongIds = [];
  Map<int, int> _playCounts = {};
  SongModel? _currentSong;
  String? _selectedFolderPath;
  String? _selectedAlbum;
  String? _selectedArtist;
  bool _isLoading = false;
  bool _hasPermission = false;
  bool _isShuffleEnabled = false;
  bool _isRepeatEnabled = false;
  bool _hasStartedPlayback = false;
  bool? _preloadQueueOverride;
  int _selectedTab = 0;
  bool _notificationPermissionRequested = false;
  String? _loadError;
  String? _homeFilter;
  int? _lastRecordedSongId;
  DateTime? _lastRecordedAt;
  StreamSubscription<int?>? _currentIndexSubscription;
  StreamSubscription<int?>? _audioSessionIdSubscription;
  StreamSubscription<bool>? _playingSubscription;
  Timer? _sessionSaveDebounce;
  Timer? _sessionSaveTicker;
  PlaybackSession? _pendingPlaybackSession;
  late final PlaybackTransitionController _transitionController;
  bool _isLoadingEqualizer = false;
  bool _sessionRestoreHandled = false;
  bool _sessionSaveErrorShown = false;

  List<SongModel> get _visibleSongs {
    final query = _searchController.text.trim().toLowerCase();
    final visibleSongs = _songs.where((song) {
      final matchesQuery =
          query.isEmpty ||
          song.title.toLowerCase().contains(query) ||
          (song.artist ?? '').toLowerCase().contains(query) ||
          (song.album ?? '').toLowerCase().contains(query);
      final matchesAlbum =
          _selectedAlbum == null || song.album == _selectedAlbum;
      final matchesArtist =
          _selectedArtist == null || song.artist == _selectedArtist;
      final matchesHomeFilter = switch (_homeFilter) {
        'favorites' => _favoriteSongIds.contains(song.id),
        'history' => _recentSongIds.contains(song.id),
        'mostPlayed' => (_playCounts[song.id] ?? 0) > 0,
        _ => true,
      };
      return matchesQuery && matchesAlbum && matchesArtist && matchesHomeFilter;
    }).toList();
    if (_homeFilter == 'history') {
      visibleSongs.sort(
        (a, b) => _recentSongIds
            .indexOf(a.id)
            .compareTo(_recentSongIds.indexOf(b.id)),
      );
    } else if (_homeFilter == 'mostPlayed') {
      visibleSongs.sort(
        (a, b) => (_playCounts[b.id] ?? 0).compareTo(_playCounts[a.id] ?? 0),
      );
    }
    return visibleSongs;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _transitionController = PlaybackTransitionController(_audioPlayer)
      ..configure(
        enabled: widget.smoothTransitionsEnabled,
        duration: Duration(seconds: widget.transitionDurationSeconds),
      );
    unawaited(_equalizer.setEnabled(widget.equalizerEnabled));
    _audioSessionIdSubscription = _audioPlayer.androidAudioSessionIdStream
        .listen((sessionId) {
          if (sessionId != null) unawaited(_loadEqualizerParameters());
        });
    _currentIndexSubscription = _audioPlayer.currentIndexStream.listen((index) {
      if (!_hasStartedPlayback ||
          index == null ||
          index < 0 ||
          index >= _playbackQueue.length) {
        return;
      }
      final song = _playbackQueue[index];
      if (_currentSong?.id == song.id) return;
      _currentSong = song;
      _currentSongNotifier.value = song;
      unawaited(_recordPlayedSong(song));
      _schedulePlaybackSessionSave();
      if (mounted) setState(() {});
    });
    _playingSubscription = _audioPlayer.playingStream.listen((playing) {
      if (!playing) {
        _schedulePlaybackSessionSave(const Duration(milliseconds: 250));
      }
    });
    _sessionSaveTicker = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_audioPlayer.playing) unawaited(_persistPlaybackSession());
    });
    unawaited(_restoreListeningData());
    unawaited(_restorePlaylistsAndLibrary());
  }

  Future<void> _restorePlaylistsAndLibrary() async {
    await _restorePlaylists();
    await _restoreLibrary();
  }

  @override
  void didUpdateWidget(covariant MusicHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.equalizerEnabled != widget.equalizerEnabled) {
      unawaited(_applyEqualizerEnabled(widget.equalizerEnabled));
    }
    if (oldWidget.equalizerPreset != widget.equalizerPreset ||
        !listEquals(oldWidget.equalizerBandGains, widget.equalizerBandGains)) {
      unawaited(_applySavedEqualizerSettings());
    }
    if (oldWidget.smoothTransitionsEnabled != widget.smoothTransitionsEnabled ||
        oldWidget.transitionDurationSeconds !=
            widget.transitionDurationSeconds) {
      _transitionController.configure(
        enabled: widget.smoothTransitionsEnabled,
        duration: Duration(seconds: widget.transitionDurationSeconds),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _currentIndexSubscription?.cancel();
    _audioSessionIdSubscription?.cancel();
    _playingSubscription?.cancel();
    _sessionSaveDebounce?.cancel();
    _sessionSaveTicker?.cancel();
    unawaited(_transitionController.dispose());
    _searchController.dispose();
    _currentSongNotifier.dispose();
    _equalizerStateNotifier.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_persistPlaybackSession());
    }
  }

  void _schedulePlaybackSessionSave([
    Duration delay = const Duration(milliseconds: 700),
  ]) {
    _sessionSaveDebounce?.cancel();
    _sessionSaveDebounce = Timer(delay, () {
      unawaited(_persistPlaybackSession());
    });
  }

  Future<void> _persistPlaybackSession() async {
    if (_playbackQueue.isEmpty) return;
    final session = PlaybackSession(
      queuePaths: _playbackQueue.map((song) => song.data).toList(),
      currentTrackPath: _currentSong?.data,
      positionMilliseconds: _currentSong == null
          ? 0
          : _audioPlayer.position.inMilliseconds,
      playlistId: _activePlaylistId,
    );
    try {
      await _preferences.setString(
        _playbackSessionPreferenceKey,
        jsonEncode(session.toJson()),
      );
      _sessionSaveErrorShown = false;
    } catch (error) {
      debugPrint('No se pudo guardar la sesión de reproducción: $error');
      if (_sessionSaveErrorShown || !mounted) return;
      _sessionSaveErrorShown = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar tu progreso')),
      );
    }
  }

  Future<void> _clearPlaybackSession() async {
    _sessionSaveDebounce?.cancel();
    try {
      await _preferences.remove(_playbackSessionPreferenceKey);
    } catch (error) {
      debugPrint('No se pudo borrar la sesión de reproducción: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo borrar la sesión guardada')),
      );
    }
  }

  Future<void> _loadEqualizerParameters() async {
    if (_isLoadingEqualizer || _equalizerStateNotifier.value.isAvailable) {
      return;
    }
    _isLoadingEqualizer = true;
    try {
      final parameters = await _equalizer.parameters.timeout(
        const Duration(seconds: 5),
      );
      final frequencies = parameters.bands
          .map((band) => band.centerFrequency)
          .toList(growable: false);
      final savedGains = widget.equalizerBandGains;
      final gains = savedGains.length == frequencies.length
          ? savedGains
          : equalizerGainsForPreset(
              preset: widget.equalizerPreset,
              centerFrequencies: frequencies,
              minGain: parameters.minDecibels,
              maxGain: parameters.maxDecibels,
            );
      for (var index = 0; index < gains.length; index++) {
        await parameters.bands[index].setGain(gains[index]);
      }
      _equalizerStateNotifier.value = EqualizerState(
        minGain: parameters.minDecibels,
        maxGain: parameters.maxDecibels,
        centerFrequencies: frequencies,
        gains: gains,
      );
      await _equalizer.setEnabled(widget.equalizerEnabled);
      if (savedGains.length != gains.length) {
        await widget.onEqualizerBandGainsChanged(gains);
      }
    } catch (error) {
      debugPrint('No se pudo iniciar el ecualizador nativo: $error');
      _equalizerStateNotifier.value = EqualizerState(
        error: 'Ecualizador no disponible en este dispositivo: $error',
      );
    } finally {
      _isLoadingEqualizer = false;
    }
  }

  Future<void> _setEqualizerEnabled(bool enabled) async {
    try {
      await _applyEqualizerEnabled(enabled);
      await widget.onEqualizerEnabledChanged(enabled);
    } catch (error) {
      _equalizerStateNotifier.value = EqualizerState(
        error: 'No se pudo cambiar el ecualizador: $error',
      );
    }
  }

  Future<void> _applyEqualizerEnabled(bool enabled) async {
    await _equalizer.setEnabled(enabled);
  }

  Future<void> _applySavedEqualizerSettings() async {
    final state = _equalizerStateNotifier.value;
    if (!state.isAvailable) return;
    final gains =
        widget.equalizerBandGains.length == state.centerFrequencies.length
        ? widget.equalizerBandGains
        : equalizerGainsForPreset(
            preset: widget.equalizerPreset,
            centerFrequencies: state.centerFrequencies,
            minGain: state.minGain,
            maxGain: state.maxGain,
          );
    await _applyEqualizerGains(gains, preset: widget.equalizerPreset);
  }

  Future<void> _setEqualizerPreset(String preset) async {
    await widget.onEqualizerPresetChanged(preset);
    final state = _equalizerStateNotifier.value;
    if (!state.isAvailable) return;
    final gains = equalizerGainsForPreset(
      preset: preset,
      centerFrequencies: state.centerFrequencies,
      minGain: state.minGain,
      maxGain: state.maxGain,
    );
    await _applyEqualizerGains(gains, preset: preset);
  }

  Future<void> _setEqualizerBandGain(int index, double gain) async {
    final state = _equalizerStateNotifier.value;
    if (!state.isAvailable || index < 0 || index >= state.gains.length) return;
    final gains = List<double>.of(state.gains);
    gains[index] = gain.clamp(state.minGain, state.maxGain).toDouble();
    await _applyEqualizerGains(gains, preset: 'custom');
  }

  Future<void> _applyEqualizerGains(
    List<double> gains, {
    required String preset,
  }) async {
    try {
      final parameters = await _equalizer.parameters;
      for (var index = 0; index < gains.length; index++) {
        await parameters.bands[index].setGain(gains[index]);
      }
      final state = _equalizerStateNotifier.value;
      _equalizerStateNotifier.value = EqualizerState(
        minGain: state.minGain,
        maxGain: state.maxGain,
        centerFrequencies: state.centerFrequencies,
        gains: gains,
      );
      await widget.onEqualizerPresetChanged(preset);
      await widget.onEqualizerBandGainsChanged(gains);
    } catch (error) {
      _equalizerStateNotifier.value = EqualizerState(
        error: 'No se pudieron aplicar las bandas del ecualizador: $error',
      );
    }
  }

  Future<void> _setSmoothTransitionsEnabled(bool enabled) async {
    await widget.onSmoothTransitionsEnabledChanged(enabled);
    _transitionController.configure(
      enabled: enabled,
      duration: Duration(seconds: widget.transitionDurationSeconds),
    );
  }

  Future<void> _setTransitionDuration(int seconds) async {
    await widget.onTransitionDurationChanged(seconds);
    _transitionController.configure(
      enabled: widget.smoothTransitionsEnabled,
      duration: Duration(seconds: seconds),
    );
  }

  Future<void> _restoreLibrary() async {
    try {
      final path = await _preferences.getString(_folderPreferenceKey);
      final sessionJson = await _preferences.getString(
        _playbackSessionPreferenceKey,
      );
      if (sessionJson != null) {
        try {
          final decoded = jsonDecode(sessionJson);
          if (decoded is! Map<String, dynamic>) {
            throw const FormatException(
              'El formato de la sesión de reproducción no es válido',
            );
          }
          _pendingPlaybackSession = PlaybackSession.fromJson(decoded);
        } catch (error) {
          _sessionRestoreHandled = true;
          debugPrint('No se pudo recuperar la sesión de reproducción: $error');
          try {
            await _preferences.remove(_playbackSessionPreferenceKey);
          } catch (removeError) {
            debugPrint(
              'No se pudo borrar la sesión de reproducción dañada: $removeError',
            );
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No se pudo recuperar la reproducción anterior'),
              ),
            );
          }
        }
      } else {
        _sessionRestoreHandled = true;
      }
      if (!mounted || path == null || path.isEmpty) return;
      setState(() {
        _selectedFolderPath = path;
      });
      await _loadSongs(folderPath: path);
    } catch (error) {
      _sessionRestoreHandled = true;
      _pendingPlaybackSession = null;
      debugPrint('No se pudo recuperar la sesión de reproducción: $error');
      if (!mounted) return;
      setState(() {
        _loadError = 'No se pudo recuperar la carpeta guardada: $error';
      });
    }
  }

  Future<void> _restoreListeningData() async {
    try {
      final favorites = await _preferences.getStringList(
        _favoritesPreferenceKey,
      );
      final history = await _preferences.getStringList(_historyPreferenceKey);
      final countsJson = await _preferences.getString(_playCountsPreferenceKey);
      if (!mounted) return;
      setState(() {
        _favoriteSongIds
          ..clear()
          ..addAll((favorites ?? []).map(int.tryParse).whereType<int>());
        _recentSongIds = (history ?? [])
            .map(int.tryParse)
            .whereType<int>()
            .toList();
        if (countsJson != null) {
          final decoded = jsonDecode(countsJson) as Map<String, dynamic>;
          final parsedCounts = <int, int>{};
          for (final entry in decoded.entries) {
            final id = int.tryParse(entry.key);
            if (id == null) continue;
            parsedCounts[id] = (entry.value as num).toInt();
          }
          _playCounts = parsedCounts;
        }
      });
    } catch (error) {
      debugPrint('No se pudo recuperar el historial local: $error');
    }
  }

  Future<void> _restorePlaylists() async {
    try {
      final savedPlaylists = await _preferences.getString(
        _playlistsPreferenceKey,
      );
      if (savedPlaylists == null) return;
      final decoded = jsonDecode(savedPlaylists);
      if (decoded is! List) {
        throw const FormatException('El formato de playlists no es válido');
      }
      final playlists = decoded
          .whereType<Map<String, dynamic>>()
          .map(Playlist.fromJson)
          .toList();
      if (!mounted) return;
      setState(() => _playlists = playlists);
    } catch (error) {
      debugPrint('No se pudieron recuperar las playlists: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron cargar las playlists')),
      );
    }
  }

  Future<void> _savePlaylists(List<Playlist> playlists) async {
    await _preferences.setString(
      _playlistsPreferenceKey,
      jsonEncode(playlists.map((playlist) => playlist.toJson()).toList()),
    );
    if (mounted) setState(() => _playlists = List.of(playlists));
  }

  void _showPlaylistMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _addSongToPlaylist(SongModel song, Playlist playlist) async {
    final updatedPlaylist = playlist.addTrack(song.data);
    if (updatedPlaylist == null) {
      _showPlaylistMessage('Esta canción ya pertenece a "${playlist.name}".');
      return;
    }
    final updatedPlaylists = _playlists
        .map((item) => item.id == playlist.id ? updatedPlaylist : item)
        .toList();
    try {
      await _savePlaylists(updatedPlaylists);
      _showPlaylistMessage('Agregada a "${playlist.name}".');
    } catch (error) {
      _showPlaylistMessage('No se pudo guardar la playlist: $error');
    }
  }

  Future<void> _showAddSongToPlaylist(SongModel song) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                'Gestionar playlists',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
            ),
            for (final playlist in _playlists) ...[
              Builder(
                builder: (context) {
                  final containsSong = playlist.trackPaths.contains(song.data);
                  return ListTile(
                    leading: Icon(
                      containsSong
                          ? Icons.check_circle_outline_rounded
                          : Icons.queue_music_rounded,
                    ),
                    title: Text(playlist.name),
                    subtitle: Text(
                      containsSong
                          ? 'Ya pertenece · ${playlist.trackPaths.length} canciones'
                          : '${playlist.trackPaths.length} canciones',
                    ),
                    trailing: Icon(
                      containsSong ? Icons.remove_circle_outline : Icons.add,
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      if (containsSong) {
                        _removeSongFromPlaylist(song, playlist);
                      } else {
                        _addSongToPlaylist(song, playlist);
                      }
                    },
                  );
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.add_circle_outline_rounded),
              title: const Text('Crear nueva playlist'),
              onTap: () {
                Navigator.pop(sheetContext);
                _createPlaylistWithSong(song);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeSongFromPlaylist(
    SongModel song,
    Playlist playlist,
  ) async {
    final updatedPlaylist = playlist.removeTrack(song.data);
    final updatedPlaylists = _playlists
        .map((item) => item.id == playlist.id ? updatedPlaylist : item)
        .toList();
    try {
      await _savePlaylists(updatedPlaylists);
      _showPlaylistMessage('Quitada de "${playlist.name}".');
    } catch (error) {
      _showPlaylistMessage('No se pudo guardar la playlist: $error');
    }
  }

  Future<void> _createPlaylistWithSong(SongModel song) async {
    var enteredName = '';
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva playlist'),
        content: TextFormField(
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Nombre de la playlist'),
          onChanged: (value) => enteredName = value,
          onFieldSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, enteredName.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    final playlist = Playlist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      trackPaths: [song.data],
    );
    try {
      await _savePlaylists([..._playlists, playlist]);
      _showPlaylistMessage('Playlist "${playlist.name}" creada.');
    } catch (error) {
      _showPlaylistMessage('No se pudo guardar la playlist: $error');
    }
  }

  Future<void> _openPlaylists() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => PlaylistLibraryPage(
          playlists: _playlists,
          songs: _songs,
          audioQuery: _audioQuery,
          onChanged: _savePlaylists,
          onPlay: _playPlaylist,
          onAddNext: _addSongToPlayNext,
        ),
      ),
    );
  }

  Future<void> _playPlaylist(
    String playlistId,
    List<SongModel> songs,
    int startIndex,
    bool openPlayer,
  ) async {
    if (songs.isEmpty || startIndex < 0 || startIndex >= songs.length) return;
    try {
      await _requestNotificationPermission();
      if (_isShuffleEnabled) {
        await _audioPlayer.setShuffleModeEnabled(false);
        _isShuffleEnabled = false;
        if (mounted) setState(() {});
      }
      await _configureQueue(songs, playlistId: playlistId);
      _hasStartedPlayback = true;
      final song = songs[startIndex];
      await _audioPlayer.seek(Duration.zero, index: startIndex);
      if (!mounted) return;
      setState(() => _currentSong = song);
      _currentSongNotifier.value = song;
      unawaited(_recordPlayedSong(song));
      unawaited(_resumePlayback());
      if (openPlayer) await _openNowPlaying();
    } catch (error) {
      _showPlaybackError(error);
    }
  }

  Future<void> _addSongToPlayNext(SongModel song) async {
    final currentSong = _currentSong;
    final queue = PlaybackQueue.insertNext(
      _playbackQueue,
      song,
      pathOf: (item) => item.data,
      currentPath: currentSong?.data,
    );
    if (queue == null) {
      _showPlaybackMessage('Esta canción ya está sonando.');
      return;
    }
    final wasAlreadyQueued = _playbackQueue.any(
      (item) => item.data == song.data,
    );
    if (!wasAlreadyQueued) _activePlaylistId = null;
    await _replacePlaybackQueue(
      queue,
      currentSong: currentSong,
      position: _audioPlayer.position,
      wasPlaying: _audioPlayer.playing,
    );
    if (mounted) _showPlaybackMessage('Se reproducirá a continuación.');
  }

  Future<void> _replacePlaybackQueue(
    List<SongModel> queue, {
    required SongModel? currentSong,
    required Duration position,
    required bool wasPlaying,
  }) async {
    try {
      final currentPath = currentSong?.data;
      final playlistId = _activePlaylistId;
      if (_isShuffleEnabled) {
        await _audioPlayer.setShuffleModeEnabled(false);
        _isShuffleEnabled = false;
      }
      await _configureQueue(queue, playlistId: playlistId);
      if (queue.isEmpty) {
        _currentSong = null;
        _currentSongNotifier.value = null;
        _hasStartedPlayback = false;
        _activePlaylistId = null;
        await _clearPlaybackSession();
      } else if (currentPath != null) {
        var index = queue.indexWhere((song) => song.data == currentPath);
        var restoredPosition = position;
        if (index < 0) {
          index = 0;
          restoredPosition = Duration.zero;
        }
        final song = queue[index];
        final duration = Duration(milliseconds: song.duration ?? 0);
        if (duration > Duration.zero && restoredPosition > duration) {
          restoredPosition = duration;
        }
        await _audioPlayer.seek(restoredPosition, index: index);
        _hasStartedPlayback = true;
        _currentSong = song;
        _currentSongNotifier.value = song;
        if (wasPlaying) unawaited(_resumePlayback());
        _schedulePlaybackSessionSave();
      } else {
        _hasStartedPlayback = false;
        _currentSong = null;
        _currentSongNotifier.value = null;
        _schedulePlaybackSessionSave();
      }
      if (mounted) setState(() {});
    } catch (error) {
      _showPlaybackError(error);
    }
  }

  void _showPlaybackMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _playQueueAt(int index, {bool openPlayer = false}) async {
    if (index < 0 || index >= _playbackQueue.length) return;
    final queue = List<SongModel>.of(_playbackQueue);
    final playlistId = _activePlaylistId;
    if (playlistId != null) {
      await _playPlaylist(playlistId, queue, index, openPlayer);
      return;
    }
    final song = queue[index];
    try {
      await _requestNotificationPermission();
      _hasStartedPlayback = true;
      await _audioPlayer.seek(Duration.zero, index: index);
      if (!mounted) return;
      setState(() => _currentSong = song);
      _currentSongNotifier.value = song;
      unawaited(_resumePlayback());
      if (openPlayer) await _openNowPlaying();
    } catch (error) {
      _showPlaybackError(error);
    }
  }

  Future<void> _toggleFavorite(SongModel song) async {
    setState(() {
      if (!_favoriteSongIds.add(song.id)) {
        _favoriteSongIds.remove(song.id);
      }
    });
    try {
      await _preferences.setStringList(
        _favoritesPreferenceKey,
        _favoriteSongIds.map((id) => id.toString()).toList(),
      );
    } catch (error) {
      debugPrint('No se pudieron guardar los favoritos: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el favorito')),
      );
    }
  }

  Future<void> _recordPlayedSong(SongModel song) async {
    final now = DateTime.now();
    if (_lastRecordedSongId == song.id &&
        _lastRecordedAt != null &&
        now.difference(_lastRecordedAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastRecordedSongId = song.id;
    _lastRecordedAt = now;
    if (!mounted) return;
    setState(() {
      _playCounts[song.id] = (_playCounts[song.id] ?? 0) + 1;
      _recentSongIds
        ..remove(song.id)
        ..insert(0, song.id);
      if (_recentSongIds.length > 50) {
        _recentSongIds = _recentSongIds.take(50).toList();
      }
    });
    try {
      await Future.wait([
        _preferences.setStringList(
          _historyPreferenceKey,
          _recentSongIds.map((id) => id.toString()).toList(),
        ),
        _preferences.setString(
          _playCountsPreferenceKey,
          jsonEncode(_playCounts.map((key, value) => MapEntry('$key', value))),
        ),
      ]);
    } catch (error) {
      debugPrint('No se pudo guardar el historial de reproducción: $error');
    }
  }

  void _selectHomeFilter(String? filter) {
    setState(() {
      _homeFilter = filter;
      _selectedTab = 0;
      _selectedAlbum = null;
      _selectedArtist = null;
      _searchController.clear();
    });
  }

  Future<void> _playRandom() async {
    if (_songs.isEmpty) return;
    final candidates = _songs
        .where((song) => song.id != _currentSong?.id)
        .toList();
    final pool = candidates.isEmpty ? _songs : candidates;
    await _playSong(pool[Random().nextInt(pool.length)], openPlayer: true);
  }

  Future<void> _showQueue() async {
    if (_playbackQueue.isEmpty && _songs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero selecciona una carpeta musical')),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.76,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Cola de reproducción · ${_playbackQueue.length}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      TextButton(
                        onPressed: _playbackQueue.isEmpty
                            ? null
                            : () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Vaciar cola'),
                                    content: const Text(
                                      '¿Quieres quitar todas las canciones de la cola?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, true),
                                        child: const Text('Vaciar'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true) return;
                                await _replacePlaybackQueue(
                                  const [],
                                  currentSong: null,
                                  position: Duration.zero,
                                  wasPlaying: false,
                                );
                                if (context.mounted) {
                                  setSheetState(() {});
                                }
                              },
                        child: const Text('Vaciar'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _playbackQueue.isEmpty
                      ? const Center(child: Text('La cola está vacía'))
                      : ReorderableListView.builder(
                          itemCount: _playbackQueue.length,
                          onReorderItem: (oldIndex, newIndex) async {
                            final queue = PlaybackQueue.reorder(
                              _playbackQueue,
                              oldIndex,
                              newIndex,
                            );
                            final currentSong = _currentSong;
                            final position = _audioPlayer.position;
                            final wasPlaying = _audioPlayer.playing;
                            await _replacePlaybackQueue(
                              queue,
                              currentSong: currentSong,
                              position: position,
                              wasPlaying: wasPlaying,
                            );
                            if (context.mounted) setSheetState(() {});
                          },
                          itemBuilder: (context, index) {
                            final song = _playbackQueue[index];
                            final isCurrent = song.data == _currentSong?.data;
                            return ListTile(
                              key: ValueKey(song.data),
                              leading: isCurrent
                                  ? Icon(
                                      Icons.equalizer_rounded,
                                      color: _accent,
                                    )
                                  : Text('${index + 1}'),
                              title: Text(song.title, maxLines: 1),
                              subtitle: Text(
                                song.artist ?? 'Artista desconocido',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Quitar de la cola',
                                    onPressed: () async {
                                      final queue = PlaybackQueue.removeAt(
                                        _playbackQueue,
                                        index,
                                      );
                                      final currentSong = _currentSong;
                                      final position = _audioPlayer.position;
                                      final wasPlaying = _audioPlayer.playing;
                                      final removingCurrent =
                                          song.data == currentSong?.data;
                                      final nextSong =
                                          removingCurrent && queue.isNotEmpty
                                          ? queue[min(index, queue.length - 1)]
                                          : currentSong;
                                      await _replacePlaybackQueue(
                                        queue,
                                        currentSong: nextSong,
                                        position: removingCurrent
                                            ? Duration.zero
                                            : position,
                                        wasPlaying: wasPlaying,
                                      );
                                      if (context.mounted) {
                                        setSheetState(() {});
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 20,
                                    ),
                                  ),
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Icon(Icons.drag_handle_rounded),
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _playQueueAt(index, openPlayer: true);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectFolder({bool returnToLibrary = false}) async {
    try {
      final folderPath = await FilePicker.getDirectoryPath(
        dialogTitle: 'Selecciona la carpeta de música',
      );
      if (folderPath == null || !mounted) return;
      _pendingPlaybackSession = null;
      _sessionRestoreHandled = true;
      await _clearPlaybackSession();
      setState(() {
        _selectedFolderPath = folderPath;
        _songs = [];
        _selectedAlbum = null;
        _selectedArtist = null;
        _searchController.clear();
      });
      await _preferences.setString(_folderPreferenceKey, folderPath);
      await _loadSongs(folderPath: folderPath, preservePlayback: false);
      if (returnToLibrary && mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo seleccionar la carpeta: $error')),
      );
    }
  }

  Future<void> _loadSongs({
    String? folderPath,
    bool preservePlayback = true,
  }) async {
    final selectedPath = folderPath ?? _selectedFolderPath;
    if (selectedPath == null) return;
    final previousSong = preservePlayback ? _currentSong : null;
    final previousPosition = _audioPlayer.position;
    final wasPlaying = preservePlayback && _audioPlayer.playing;
    final previousQueue = preservePlayback && _playbackQueue.isNotEmpty
        ? List<SongModel>.of(_playbackQueue)
        : null;
    final previousPlaylistId = previousQueue == null ? null : _activePlaylistId;

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      var permissionGranted = await _audioQuery.permissionsStatus();
      if (!permissionGranted) {
        permissionGranted = await _audioQuery.permissionsRequest();
      }
      if (!mounted) return;

      if (!permissionGranted) {
        setState(() {
          _hasPermission = false;
          _isLoading = false;
        });
        return;
      }

      final normalizedFolder = _normalizePath(selectedPath);
      List<SongModel> songs = [];
      for (var attempt = 0; attempt < 3; attempt++) {
        final queriedSongs = await _audioQuery.querySongs(
          uriType: UriType.EXTERNAL,
          sortType: SongSortType.TITLE,
          ignoreCase: true,
          path: normalizedFolder,
        );
        if (!mounted) return;
        songs = queriedSongs.where((song) {
          final songPath = _normalizePath(song.data);
          return songPath.startsWith('$normalizedFolder/') &&
              isSupportedAudioPath(song.data) &&
              (!widget.skipShortTracks || (song.duration ?? 0) >= 30000);
        }).toList();
        if (songs.isNotEmpty || attempt == 2) break;
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }

      setState(() {
        _hasPermission = true;
        _songs = songs;
        _selectedAlbum = null;
        _selectedArtist = null;
      });
      if (_pendingPlaybackSession != null && !_sessionRestoreHandled) {
        await _restorePlaybackSession(songs);
      } else {
        final queue = previousQueue ?? songs;
        await _configureQueue(queue, playlistId: previousPlaylistId);
      }
      if (previousSong != null) {
        final index = _playbackQueue.indexWhere(
          (song) => song.data == previousSong.data,
        );
        if (index >= 0) {
          _hasStartedPlayback = true;
          await _audioPlayer.seek(previousPosition, index: index);
          _currentSong = _playbackQueue[index];
          _currentSongNotifier.value = _currentSong;
          if (wasPlaying) unawaited(_resumePlayback());
          if (mounted) setState(() {});
        }
      }
      _schedulePlaybackSessionSave();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = 'No se pudo leer la música del teléfono: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _restorePlaybackSession(List<SongModel> songs) async {
    final session = _pendingPlaybackSession!;
    final songsByPath = {for (final song in songs) song.data: song};
    var queue = session.queuePaths
        .map((path) => songsByPath[path])
        .whereType<SongModel>()
        .toList();
    if (queue.isEmpty) queue = List.of(songs);
    final restoredPlaylistId =
        _playlists.any((playlist) => playlist.id == session.playlistId)
        ? session.playlistId
        : null;
    await _configureQueue(queue, playlistId: restoredPlaylistId);
    _sessionRestoreHandled = true;
    _pendingPlaybackSession = null;

    final currentIndex = session.currentTrackPath == null
        ? -1
        : queue.indexWhere((song) => song.data == session.currentTrackPath);
    if (currentIndex >= 0) {
      final song = queue[currentIndex];
      final savedPosition = Duration(
        milliseconds: session.positionMilliseconds,
      );
      final duration = Duration(milliseconds: song.duration ?? 0);
      final position = duration > Duration.zero && savedPosition > duration
          ? duration
          : savedPosition;
      _hasStartedPlayback = true;
      await _audioPlayer.seek(position, index: currentIndex);
      _currentSong = song;
      _currentSongNotifier.value = song;
      unawaited(_recordPlayedSong(song));
    }
    if (mounted) setState(() {});
    await _persistPlaybackSession();
  }

  Future<void> _playSong(SongModel song, {bool openPlayer = false}) async {
    try {
      await _requestNotificationPermission();
      if (_activePlaylistId != null) {
        await _configureQueue(_songs);
      }
      var index = _playbackQueue.indexWhere((item) => item.data == song.data);
      if (index < 0) {
        await _configureQueue(_songs);
        index = _playbackQueue.indexWhere((item) => item.data == song.data);
      }
      if (index < 0) return;
      if (_audioPlayer.sequence?.isEmpty ?? true) {
        await _configureQueue(_songs);
        index = _playbackQueue.indexWhere((item) => item.data == song.data);
      }
      _hasStartedPlayback = true;
      await _audioPlayer.seek(Duration.zero, index: index);
      if (!mounted) return;
      setState(() {
        _currentSong = _playbackQueue[index];
      });
      _currentSongNotifier.value = _playbackQueue[index];
      _schedulePlaybackSessionSave();
      unawaited(_resumePlayback());
      if (openPlayer && mounted) {
        await _openNowPlaying();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo reproducir "${song.title}": $error'),
        ),
      );
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (_notificationPermissionRequested ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _notificationPermissionRequested = true;
    try {
      await Permission.notification.request();
    } catch (error) {
      debugPrint('No se pudo solicitar permiso para notificaciones: $error');
    }
  }

  Future<void> _resumePlayback() async {
    try {
      await _audioPlayer.play();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo iniciar la reproducción: $error')),
      );
    }
  }

  Future<void> _playNext() async {
    if (_playbackQueue.isEmpty) return;
    try {
      if (_currentSong == null) {
        await _playSong(_playbackQueue.first);
      } else {
        await _audioPlayer.seekToNext();
      }
    } catch (error) {
      _showPlaybackError(error);
    }
  }

  Future<void> _playPrevious() async {
    if (_playbackQueue.isEmpty) return;

    try {
      if (_audioPlayer.position > const Duration(seconds: 3)) {
        await _audioPlayer.seek(Duration.zero);
      } else {
        await _audioPlayer.seekToPrevious();
      }
    } catch (error) {
      _showPlaybackError(error);
    }
  }

  Future<void> _setShuffle(bool enabled) async {
    await _audioPlayer.setShuffleModeEnabled(enabled);
    if (enabled) _audioPlayer.shuffle();
    if (mounted) {
      setState(() {
        _isShuffleEnabled = enabled;
      });
    }
  }

  Future<void> _setRepeat(bool enabled) async {
    await _audioPlayer.setLoopMode(enabled ? LoopMode.one : LoopMode.off);
    if (mounted) setState(() => _isRepeatEnabled = enabled);
  }

  Future<void> _setQueuePreload(bool enabled) async {
    final wasPlaying = _audioPlayer.playing;
    final currentIndex = _audioPlayer.currentIndex;
    final queue = List<SongModel>.of(_playbackQueue);
    final playlistId = _activePlaylistId;
    _preloadQueueOverride = enabled;
    try {
      await widget.onPreloadQueueChanged(enabled);
      if (!mounted || queue.isEmpty) return;
      await _configureQueue(queue, playlistId: playlistId);
      if (currentIndex != null && currentIndex < queue.length) {
        _hasStartedPlayback = true;
        await _audioPlayer.seek(Duration.zero, index: currentIndex);
        _currentSong = queue[currentIndex];
        _currentSongNotifier.value = _currentSong;
        if (wasPlaying) unawaited(_resumePlayback());
        setState(() {});
      }
    } catch (error) {
      _showPlaybackError(error);
    } finally {
      _preloadQueueOverride = null;
    }
  }

  Future<void> _configureQueue(
    List<SongModel> songs, {
    String? playlistId,
  }) async {
    await _audioPlayer.stop();
    _hasStartedPlayback = false;
    _currentSong = null;
    _currentSongNotifier.value = null;
    _playbackQueue = List.of(songs);
    _activePlaylistId = playlistId;
    if (songs.isEmpty) return;
    final children = songs
        .map((song) {
          return AudioSource.uri(
            File(song.data).uri,
            tag: MediaItem(
              id: song.id.toString(),
              title: song.title,
              album: song.album,
              artist: song.artist,
              duration: Duration(milliseconds: song.duration ?? 0),
            ),
          );
        })
        .toList(growable: false);
    await _audioPlayer.setAudioSource(
      ConcatenatingAudioSource(
        children: children,
        useLazyPreparation: !(_preloadQueueOverride ?? widget.preloadQueue),
      ),
      initialIndex: 0,
    );
    await _audioPlayer.setShuffleModeEnabled(_isShuffleEnabled);
    await _audioPlayer.setLoopMode(
      _isRepeatEnabled ? LoopMode.one : LoopMode.off,
    );
  }

  void _showPlaybackError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Error del reproductor: $error')));
  }

  Future<void> _openNowPlaying() async {
    if (_currentSong == null) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => NowPlayingPage(
          currentSong: _currentSongNotifier,
          audioQuery: _audioQuery,
          audioPlayer: _audioPlayer,
          sleepTimerState: _transitionController.sleepTimerState,
          backgroundStyle: widget.playerBackgroundStyle,
          accentColor: widget.accentColor,
          isShuffleEnabled: _isShuffleEnabled,
          isRepeatEnabled: _isRepeatEnabled,
          onPrevious: _playPrevious,
          onNext: _playNext,
          onStartSleepTimer: (duration) {
            if (duration == null) {
              _transitionController.startEndOfTrack();
            } else {
              _transitionController.startCountdown(duration);
            }
          },
          onCancelSleepTimer: _transitionController.cancelSleepTimer,
          onShuffleChanged: _setShuffle,
          onRepeatChanged: _setRepeat,
          onAddToPlaylist: () => _showAddSongToPlaylist(_currentSong!),
          onOpenQueue: _showQueue,
          isFavorite: (songId) => _favoriteSongIds.contains(songId),
          onFavoriteChanged: () => _toggleFavorite(_currentSong!),
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => MusicSettingsPage(
          themeStyle: widget.themeStyle,
          accentColor: widget.accentColor,
          refreshRate: widget.refreshRate,
          coverStyle: widget.coverStyle,
          playerBackgroundStyle: widget.playerBackgroundStyle,
          equalizerEnabled: widget.equalizerEnabled,
          equalizerPreset: widget.equalizerPreset,
          equalizerState: _equalizerStateNotifier,
          smoothTransitionsEnabled: widget.smoothTransitionsEnabled,
          transitionDurationSeconds: widget.transitionDurationSeconds,
          preloadQueue: widget.preloadQueue,
          skipShortTracks: widget.skipShortTracks,
          selectedFolderPath: _selectedFolderPath,
          onThemeStyleChanged: widget.onThemeStyleChanged,
          onAccentColorChanged: widget.onAccentColorChanged,
          onRefreshRateChanged: widget.onRefreshRateChanged,
          onCoverStyleChanged: widget.onCoverStyleChanged,
          onPlayerBackgroundStyleChanged: widget.onPlayerBackgroundStyleChanged,
          onEqualizerEnabledChanged: _setEqualizerEnabled,
          onEqualizerPresetChanged: _setEqualizerPreset,
          onEqualizerBandGainChanged: _setEqualizerBandGain,
          onSmoothTransitionsEnabledChanged: _setSmoothTransitionsEnabled,
          onTransitionDurationChanged: _setTransitionDuration,
          onPreloadQueueChanged: _setQueuePreload,
          onSkipShortTracksChanged: (enabled) async {
            await widget.onSkipShortTracksChanged(enabled);
            if (mounted && _selectedFolderPath != null) {
              await _loadSongs();
            }
          },
          onSelectFolder: () => _selectFolder(returnToLibrary: true),
          onRescan: _loadSongs,
        ),
      ),
    );
  }

  String _normalizePath(String path) {
    var normalized = path.replaceAll('\\', '/');
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  @override
  Widget build(BuildContext context) {
    final visibleSongs = _visibleSongs;

    return Scaffold(
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
              child: Row(
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      tooltip: 'Abrir menú',
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      icon: const Icon(Icons.menu_rounded),
                    ),
                  ),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.graphic_eq, color: _accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SONORA',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          'Tu música, a tu manera',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: secondaryTextColor(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _selectedFolderPath == null
                        ? 'Seleccionar carpeta'
                        : 'Cambiar carpeta',
                    onPressed: _isLoading ? null : _selectFolder,
                    icon: const Icon(Icons.folder_open_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tu biblioteca',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _selectedFolderPath == null
                        ? 'Elige una carpeta para empezar'
                        : '${_songs.length} canciones en esta carpeta',
                    style: TextStyle(color: secondaryTextColor(context)),
                  ),
                  if (_selectedFolderPath != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _selectedFolderPath!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: secondaryTextColor(context, 0.38),
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _searchController,
                    enabled: _selectedFolderPath != null,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Buscar canción, álbum o artista',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Borrar búsqueda',
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                      filled: true,
                      fillColor: widget.themeStyle == 'light'
                          ? const Color(0xFFEFEFEF)
                          : widget.amoledMode
                          ? const Color(0xFF111111)
                          : const Color(0xFF1B1F1B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildCurrentTab(visibleSongs)),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_currentSong != null) _buildMiniPlayer(),
          NavigationBar(
            selectedIndex: _selectedTab,
            onDestinationSelected: (index) {
              setState(() {
                _selectedTab = index;
                _selectedAlbum = null;
                _selectedArtist = null;
                _homeFilter = null;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.music_note_outlined),
                selectedIcon: Icon(Icons.music_note_rounded),
                label: 'Canciones',
              ),
              NavigationDestination(
                icon: Icon(Icons.album_outlined),
                selectedIcon: Icon(Icons.album_rounded),
                label: 'Álbumes',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Artistas',
              ),
              NavigationDestination(
                icon: Icon(Icons.folder_outlined),
                selectedIcon: Icon(Icons.folder_rounded),
                label: 'Carpeta',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTab(List<SongModel> visibleSongs) {
    if (_selectedFolderPath == null || _isLoading || _loadError != null) {
      return _buildLibrary(visibleSongs);
    }

    return switch (_selectedTab) {
      0 => _buildLibrary(visibleSongs),
      1 => _buildCollectionList(
        _groupSongs(
          (song) => song.album?.trim().isNotEmpty == true
              ? song.album!.trim()
              : 'Álbum desconocido',
        ),
        isAlbum: true,
      ),
      2 => _buildCollectionList(
        _groupSongs(
          (song) => song.artist?.trim().isNotEmpty == true
              ? song.artist!.trim()
              : 'Artista desconocido',
        ),
        isAlbum: false,
      ),
      _ => _buildFolderTab(visibleSongs),
    };
  }

  Map<String, List<SongModel>> _groupSongs(String Function(SongModel) keyFor) {
    final groups = <String, List<SongModel>>{};
    for (final song in _visibleSongs) {
      groups.putIfAbsent(keyFor(song), () => <SongModel>[]).add(song);
    }
    return groups;
  }

  Widget _buildCollectionList(
    Map<String, List<SongModel>> collections, {
    required bool isAlbum,
  }) {
    if (collections.isEmpty) {
      return MessageState(
        icon: isAlbum ? Icons.album_outlined : Icons.person_outline_rounded,
        title: isAlbum ? 'No hay álbumes' : 'No hay artistas',
        message: 'Los elementos de tu carpeta aparecerán aquí.',
        compact: true,
      );
    }
    final names = collections.keys.toList()..sort();
    if (isAlbum) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.72,
        ),
        itemCount: names.length,
        itemBuilder: (context, index) {
          final name = names[index];
          final songs = collections[name]!;
          final representative = songs.first;
          return Material(
            color: widget.themeStyle == 'light'
                ? const Color(0xFFF0F0F0)
                : widget.amoledMode
                ? const Color(0xFF111111)
                : const Color(0xFF191C19),
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedAlbum = name;
                  _selectedArtist = null;
                  _selectedTab = 0;
                  _searchController.clear();
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) => CachedArtwork(
                          controller: _audioQuery,
                          id: representative.id,
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${representative.artist ?? 'Artista desconocido'} · ${songs.length} pistas',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: secondaryTextColor(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      itemCount: names.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, indent: 76, color: Color(0xFF272B27)),
      itemBuilder: (context, index) {
        final name = names[index];
        final songs = collections[name]!;
        final representative = songs.first;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 4,
          ),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedArtwork(
              controller: _audioQuery,
              id: representative.id,
              width: 58,
              height: 58,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          title: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            isAlbum
                ? '${representative.artist ?? 'Artista desconocido'} · ${songs.length} canciones'
                : '${songs.length} canciones',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: secondaryTextColor(context)),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            setState(() {
              _selectedAlbum = isAlbum ? name : null;
              _selectedArtist = isAlbum ? null : name;
              _selectedTab = 0;
              _searchController.clear();
            });
          },
        );
      },
    );
  }

  Widget _buildFolderTab(List<SongModel> visibleSongs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.themeStyle == 'light'
                  ? const Color(0xFFF0F0F0)
                  : widget.amoledMode
                  ? const Color(0xFF111111)
                  : const Color(0xFF1B1F1B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.folder_rounded, color: _accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedFolderPath ?? 'Sin carpeta seleccionada',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: _buildLibrary(visibleSongs)),
      ],
    );
  }

  Widget _buildLibrary(List<SongModel> visibleSongs) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: _accent));
    }

    if (_loadError != null) {
      return MessageState(
        icon: Icons.error_outline_rounded,
        title: 'No se pudo cargar la biblioteca',
        message: _loadError!,
        actionLabel: 'Intentar de nuevo',
        onAction: _loadSongs,
      );
    }

    if (_selectedFolderPath == null) {
      return MessageState(
        icon: Icons.folder_open_rounded,
        title: 'Elige dónde buscar tu música',
        message: 'Solo mostraremos canciones de la carpeta que selecciones. Así se excluyen tonos y audios de otras aplicaciones.',
      );
    }

    if (!_hasPermission) {
      return MessageState(
        icon: Icons.folder_open_rounded,
        title: 'Permiso necesario',
        message: 'Permite el acceso a audio para buscar las canciones guardadas en tu teléfono.',
        actionLabel: 'Dar permiso',
        onAction: _loadSongs,
      );
    }

    if (_songs.isEmpty) {
      return MessageState(
        icon: Icons.library_music_outlined,
        title: 'Tu biblioteca está vacía',
        message: 'Copia música al teléfono y toca actualizar. Los archivos FLAC también aparecerán aquí.',
        actionLabel: 'Actualizar biblioteca',
        onAction: _loadSongs,
      );
    }

    if (visibleSongs.isEmpty) {
      return const MessageState(
        icon: Icons.search_off_rounded,
        title: 'No encontramos resultados',
        message: 'Prueba con otro título, artista o álbum.',
      );
    }

    final showHomeHeader = _selectedTab == 0;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      itemCount: visibleSongs.length + (showHomeHeader ? 1 : 0),
      separatorBuilder: (context, index) => index == 0 && showHomeHeader
          ? const SizedBox(height: 0)
          : const Divider(height: 1, indent: 66, color: Color(0xFF272B27)),
      itemBuilder: (context, index) {
        if (showHomeHeader && index == 0) return _buildHomeQuickAccess();
        final song = visibleSongs[index - (showHomeHeader ? 1 : 0)];
        final isCurrent = song.id == _currentSong?.id;
        final artworkSize = widget.coverStyle == 'compact' ? 44.0 : 56.0;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 4,
          ),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedArtwork(
              controller: _audioQuery,
              id: song.id,
              width: artworkSize,
              height: artworkSize,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isCurrent
                  ? _accent
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            '${song.artist ?? 'Artista desconocido'}  ·  ${formatDuration(Duration(milliseconds: song.duration ?? 0))}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: secondaryTextColor(context), fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopupMenuButton<String>(
                tooltip: 'Más opciones de ${song.title}',
                onSelected: (action) {
                  if (action == 'next') _addSongToPlayNext(song);
                  if (action == 'playlist') _showAddSongToPlaylist(song);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'next',
                    child: Row(
                      children: [
                        Icon(Icons.queue_music_rounded),
                        SizedBox(width: 12),
                        Text('Reproducir a continuación'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'playlist',
                    child: Row(
                      children: [
                        Icon(Icons.playlist_add_rounded),
                        SizedBox(width: 12),
                        Text('Agregar a playlist'),
                      ],
                    ),
                  ),
                ],
                icon: const Icon(Icons.more_vert_rounded, size: 21),
              ),
              IconButton(
                tooltip: _favoriteSongIds.contains(song.id)
                    ? 'Quitar de favoritos'
                    : 'Añadir a favoritos',
                onPressed: () => _toggleFavorite(song),
                icon: Icon(
                  _favoriteSongIds.contains(song.id)
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: _favoriteSongIds.contains(song.id)
                      ? _accent
                      : secondaryTextColor(context, 0.6),
                  size: 21,
                ),
              ),
              Icon(
                isCurrent ? Icons.equalizer_rounded : Icons.play_arrow_rounded,
                color: _accent,
              ),
            ],
          ),
          onTap: () => _playSong(song, openPlayer: true),
        );
      },
    );
  }

  Widget _buildHomeQuickAccess() {
    final filterLabel = switch (_homeFilter) {
      'favorites' => 'Favoritos',
      'history' => 'Historial',
      'mostPlayed' => 'Más escuchadas',
      _ => null,
    };
    if (filterLabel != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                filterLabel,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: () => _selectHomeFilter(null),
              child: const Text('Ver todo'),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 108,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 12, right: 4),
        children: [
          _QuickAccessCard(
            icon: Icons.favorite_rounded,
            label: 'Favoritos',
            color: const Color(0xFFE57373),
            onTap: () => _selectHomeFilter('favorites'),
          ),
          _QuickAccessCard(
            icon: Icons.shuffle_rounded,
            label: 'Aleatorio',
            color: _accent,
            onTap: _playRandom,
          ),
          _QuickAccessCard(
            icon: Icons.trending_up_rounded,
            label: 'Más escuchadas',
            color: const Color(0xFFFFB74D),
            onTap: () => _selectHomeFilter('mostPlayed'),
          ),
          _QuickAccessCard(
            icon: Icons.history_rounded,
            label: 'Historial',
            color: const Color(0xFF64B5F6),
            onTap: () => _selectHomeFilter('history'),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPlayer() {
    final song = _currentSong!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Material(
        color: widget.themeStyle == 'light'
            ? const Color(0xFFF0F0F0)
            : const Color(0xFF202720),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _openNowPlaying,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<Duration>(
                stream: _audioPlayer.positionStream,
                builder: (context, snapshot) {
                  final duration = _audioPlayer.duration ?? Duration.zero;
                  final position = snapshot.data ?? Duration.zero;
                  final progress = duration.inMilliseconds == 0
                      ? 0.0
                      : (position.inMilliseconds / duration.inMilliseconds)
                            .clamp(0.0, 1.0);
                  return LinearProgressIndicator(
                    value: progress,
                    minHeight: 2,
                    backgroundColor: secondaryTextColor(context, 0.12),
                    color: _accent,
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedArtwork(
                        controller: _audioQuery,
                        id: song.id,
                        width: 48,
                        height: 48,
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            song.artist ?? 'Artista desconocido',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: secondaryTextColor(context),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StreamBuilder<PlayerState>(
                      stream: _audioPlayer.playerStateStream,
                      builder: (context, snapshot) {
                        final isPlaying =
                            snapshot.data?.playing ?? _audioPlayer.playing;
                        return IconButton(
                          tooltip: isPlaying ? 'Pausar' : 'Reproducir',
                          onPressed: () => isPlaying
                              ? _audioPlayer.pause()
                              : _audioPlayer.play(),
                          icon: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Theme.of(context).colorScheme.onSurface,
                            size: 30,
                          ),
                        );
                      },
                    ),
                    IconButton(
                      tooltip: 'Siguiente canción',
                      onPressed: _playNext,
                      icon: const Icon(Icons.skip_next_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            if (_currentSong != null)
              ListTile(
                leading: CachedArtwork(
                  controller: _audioQuery,
                  id: _currentSong!.id,
                  width: 52,
                  height: 52,
                  borderRadius: BorderRadius.circular(9),
                ),
                title: Text(
                  _currentSong!.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _currentSong!.artist ?? 'Artista desconocido',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _openNowPlaying();
                },
              )
            else
              const DrawerHeader(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    'SONORA',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.library_music_outlined),
              title: const Text('Biblioteca'),
              onTap: () {
                Navigator.pop(context);
                _selectHomeFilter(null);
                setState(() => _selectedTab = 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Carpetas'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedTab = 3;
                  _homeFilter = null;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music_rounded),
              title: const Text('Cola de reproducción'),
              onTap: () {
                Navigator.pop(context);
                _showQueue();
              },
            ),
            ListTile(
              leading: const Icon(Icons.library_music_rounded),
              title: const Text('Playlists'),
              onTap: () {
                Navigator.pop(context);
                _openPlaylists();
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite_border_rounded),
              title: const Text('Favoritos'),
              onTap: () {
                Navigator.pop(context);
                _selectHomeFilter('favorites');
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text('Historial y estadísticas'),
              onTap: () {
                Navigator.pop(context);
                _selectHomeFilter('history');
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: const Text('Escanear medios'),
              onTap: () {
                Navigator.pop(context);
                _loadSongs();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Configuración'),
              onTap: () {
                Navigator.pop(context);
                _openSettings();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
