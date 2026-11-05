import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import 'artwork_widgets.dart';
import 'playlist_model.dart';

class PlaylistLibraryPage extends StatefulWidget {
  const PlaylistLibraryPage({
    required this.playlists,
    required this.songs,
    required this.audioQuery,
    required this.onChanged,
    required this.onPlay,
    super.key,
  });

  final List<Playlist> playlists;
  final List<SongModel> songs;
  final OnAudioQuery audioQuery;
  final Future<void> Function(List<Playlist> playlists) onChanged;
  final Future<void> Function(
    String playlistId,
    List<SongModel> songs,
    int startIndex,
    bool openPlayer,
  )
  onPlay;

  @override
  State<PlaylistLibraryPage> createState() => _PlaylistLibraryPageState();
}

class _PlaylistLibraryPageState extends State<PlaylistLibraryPage> {
  late List<Playlist> _playlists = List.of(widget.playlists);

  @override
  void didUpdateWidget(covariant PlaylistLibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.playlists, widget.playlists)) {
      _playlists = List.of(widget.playlists);
    }
  }

  Future<void> _commit(List<Playlist> playlists) async {
    await widget.onChanged(playlists);
    if (mounted) setState(() => _playlists = playlists);
  }

  Future<String?> _askForName({String? initialName}) async {
    var enteredName = initialName ?? '';
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initialName == null ? 'Nueva playlist' : 'Renombrar playlist'),
        content: TextFormField(
          initialValue: initialName,
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
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return null;
    return name.trim();
  }

  Future<void> _createPlaylist() async {
    final name = await _askForName();
    if (name == null || !mounted) return;
    final playlist = Playlist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      trackPaths: const [],
    );
    try {
      await _commit([..._playlists, playlist]);
    } catch (error) {
      _showError('No se pudo crear la playlist: $error');
    }
  }

  Future<void> _renamePlaylist(Playlist playlist) async {
    final name = await _askForName(initialName: playlist.name);
    if (name == null || !mounted) return;
    try {
      await _commit(
        _playlists
            .map((item) => item.id == playlist.id ? item.copyWith(name: name) : item)
            .toList(),
      );
    } catch (error) {
      _showError('No se pudo renombrar la playlist: $error');
    }
  }

  Future<void> _deletePlaylist(Playlist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar playlist'),
        content: Text('¿Eliminar "${playlist.name}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _commit(_playlists.where((item) => item.id != playlist.id).toList());
    } catch (error) {
      _showError('No se pudo eliminar la playlist: $error');
    }
  }

  Future<void> _updatePlaylist(Playlist updated) async {
    await _commit(
      _playlists
          .map((playlist) => playlist.id == updated.id ? updated : playlist)
          .toList(),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlists'),
        actions: [
          IconButton(
            tooltip: 'Crear playlist',
            onPressed: _createPlaylist,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: _playlists.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.queue_music_rounded,
                      size: 56,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Todavía no tienes playlists',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Crea una lista para organizar tu música como quieras.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _createPlaylist,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Crear playlist'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _playlists.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final playlist = _playlists[index];
                final availableCount = playlist.trackPaths
                    .where((path) => widget.songs.any((song) => song.data == path))
                    .length;
                return ListTile(
                  leading: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.queue_music_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '$availableCount canciones'
                    '${availableCount < playlist.trackPaths.length ? ' · ${playlist.trackPaths.length - availableCount} no disponibles' : ''}',
                  ),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Opciones de ${playlist.name}',
                    onSelected: (value) {
                      if (value == 'rename') _renamePlaylist(playlist);
                      if (value == 'delete') _deletePlaylist(playlist);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'rename',
                        child: Text('Renombrar'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Eliminar'),
                      ),
                    ],
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => _PlaylistDetailPage(
                        playlist: playlist,
                        songs: widget.songs,
                        audioQuery: widget.audioQuery,
                        onChanged: _updatePlaylist,
                        onPlay: widget.onPlay,
                        onError: _showError,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _PlaylistDetailPage extends StatefulWidget {
  const _PlaylistDetailPage({
    required this.playlist,
    required this.songs,
    required this.audioQuery,
    required this.onChanged,
    required this.onPlay,
    required this.onError,
  });

  final Playlist playlist;
  final List<SongModel> songs;
  final OnAudioQuery audioQuery;
  final Future<void> Function(Playlist playlist) onChanged;
  final Future<void> Function(
    String playlistId,
    List<SongModel> songs,
    int startIndex,
    bool openPlayer,
  )
  onPlay;
  final ValueChanged<String> onError;

  @override
  State<_PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<_PlaylistDetailPage> {
  late Playlist _playlist = widget.playlist;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void didUpdateWidget(covariant _PlaylistDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playlist.id == widget.playlist.id &&
        oldWidget.playlist != widget.playlist) {
      _playlist = widget.playlist;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  SongModel? _songForPath(String path) {
    for (final song in widget.songs) {
      if (song.data == path) return song;
    }
    return null;
  }

  List<String> get _displayPaths {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _playlist.trackPaths;
    return _playlist.trackPaths.where((path) {
      final song = _songForPath(path);
      return song != null &&
          (song.title.toLowerCase().contains(query) ||
              (song.artist ?? '').toLowerCase().contains(query) ||
              (song.album ?? '').toLowerCase().contains(query));
    }).toList();
  }

  List<SongModel> get _availableSongs => _playlist.trackPaths
      .map(_songForPath)
      .whereType<SongModel>()
      .toList(growable: false);

  Future<void> _commit(Playlist updated) async {
    await widget.onChanged(updated);
    if (mounted) setState(() => _playlist = updated);
  }

  Future<void> _play({SongModel? song, bool openPlayer = false}) async {
    final songs = _availableSongs;
    if (songs.isEmpty) {
      widget.onError('Esta playlist no tiene canciones disponibles.');
      return;
    }
    final startIndex = song == null
        ? 0
        : songs.indexWhere((item) => item.data == song.data);
    if (startIndex < 0) return;
    await widget.onPlay(_playlist.id, songs, startIndex, openPlayer);
  }

  Future<void> _remove(String path) async {
    final updated = _playlist.removeTrack(path);
    try {
      await _commit(updated);
    } catch (error) {
      widget.onError('No se pudo quitar la canción: $error');
    }
  }

  Future<void> _add(SongModel song) async {
    final updated = _playlist.addTrack(song.data);
    if (updated == null) {
      widget.onError('Esta canción ya pertenece a "${_playlist.name}".');
      return;
    }
    try {
      await _commit(updated);
    } catch (error) {
      widget.onError('No se pudo agregar la canción: $error');
    }
  }

  Future<void> _chooseSongToAdd() async {
    var query = '';
    final selectedSong = await showModalBottomSheet<SongModel>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final songs = widget.songs.where((song) {
            final normalized = query.trim().toLowerCase();
            return normalized.isEmpty ||
                song.title.toLowerCase().contains(normalized) ||
                (song.artist ?? '').toLowerCase().contains(normalized) ||
                (song.album ?? '').toLowerCase().contains(normalized);
          }).toList();
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.78,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: TextField(
                      autofocus: true,
                      onChanged: (value) => setSheetState(() => query = value),
                      decoration: const InputDecoration(
                        hintText: 'Buscar canción',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: songs.length,
                      itemBuilder: (context, index) {
                        final song = songs[index];
                        final alreadyAdded = _playlist.trackPaths.contains(
                          song.data,
                        );
                        return ListTile(
                          leading: CachedArtwork(
                            controller: widget.audioQuery,
                            id: song.id,
                            width: 46,
                            height: 46,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          title: Text(song.title, maxLines: 1),
                          subtitle: Text(
                            song.artist ?? 'Artista desconocido',
                            maxLines: 1,
                          ),
                          trailing: Icon(
                            alreadyAdded ? Icons.check_rounded : Icons.add,
                          ),
                          onTap: () => Navigator.pop(context, song),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (selectedSong != null) await _add(selectedSong);
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    try {
      await _commit(_playlist.reorderTrack(oldIndex, newIndex));
    } catch (error) {
      widget.onError('No se pudo guardar el nuevo orden: $error');
    }
  }

  Widget _buildTrackTile(String path, int index, {required bool reorderable}) {
    final song = _songForPath(path);
    return ListTile(
      key: ValueKey(path),
      leading: song == null
          ? const SizedBox(
              width: 48,
              height: 48,
              child: Icon(Icons.music_off_outlined),
            )
          : CachedArtwork(
              controller: widget.audioQuery,
              id: song.id,
              width: 48,
              height: 48,
              borderRadius: BorderRadius.circular(8),
            ),
      title: Text(
        song?.title ?? 'Canción no disponible',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        song?.artist ?? path.split(RegExp(r'[/\\]')).last,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: song == null ? null : () => _play(song: song),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Quitar de la playlist',
            onPressed: () => _remove(path),
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          if (reorderable)
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.drag_handle_rounded),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayPaths = _displayPaths;
    final unavailableCount = _playlist.trackPaths.length - _availableSongs.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(_playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Agregar canciones',
            onPressed: widget.songs.isEmpty ? null : _chooseSongToAdd,
            icon: const Icon(Icons.playlist_add_rounded),
          ),
          IconButton(
            tooltip: 'Reproducir playlist',
            onPressed: _availableSongs.isEmpty
                ? null
                : () => _play(openPlayer: true),
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Buscar en esta playlist',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Borrar búsqueda',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          if (unavailableCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '$unavailableCount canciones no están disponibles en la carpeta actual.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          Expanded(
            child: displayPaths.isEmpty
                ? Center(
                    child: Text(
                      _playlist.trackPaths.isEmpty
                          ? 'Agrega canciones con el botón de arriba.'
                          : 'No encontramos canciones con esa búsqueda.',
                    ),
                  )
                : _query.trim().isEmpty
                ? ReorderableListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: displayPaths.length,
                    onReorderItem: _reorder,
                    buildDefaultDragHandles: false,
                    itemBuilder: (context, index) => _buildTrackTile(
                      displayPaths[index],
                      index,
                      reorderable: true,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: displayPaths.length,
                    itemBuilder: (context, index) => _buildTrackTile(
                      displayPaths[index],
                      index,
                      reorderable: false,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
