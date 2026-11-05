import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:reproductor_flac/playlist_library_page.dart';
import 'package:reproductor_flac/playlist_model.dart';

void main() {
  testWidgets('playlist songs can be reordered by dragging', (tester) async {
    var playlists = [
      const Playlist(
        id: 'mix',
        name: 'Mix',
        trackPaths: ['/music/first.flac', '/music/second.flac'],
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: PlaylistLibraryPage(
          playlists: playlists,
          songs: const [],
          audioQuery: _FakeAudioQuery(),
          onChanged: (updated) async {
            playlists = updated;
          },
          onPlay: (_, _, _, _) async {},
        ),
      ),
    );

    await tester.tap(find.text('Mix'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byIcon(Icons.drag_handle_rounded).first,
      const Offset(0, 170),
    );
    await tester.pumpAndSettle();
    expect(playlists.single.trackPaths, [
      '/music/second.flac',
      '/music/first.flac',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('playlist search, duplicate notice, and song removal work', (
    tester,
  ) async {
    final songA = SongModel({
      '_id': 1,
      '_data': '/music/track-a.flac',
      'title': 'Track A',
      'artist': 'Artist',
      'album': 'Album',
    });
    final songB = SongModel({
      '_id': 2,
      '_data': '/music/track-b.mp3',
      'title': 'Track B',
      'artist': 'Artist',
      'album': 'Album',
    });
    var playlists = [
      const Playlist(
        id: 'mix',
        name: 'Mix',
        trackPaths: ['/music/track-a.flac', '/music/track-b.mp3'],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: PlaylistLibraryPage(
          playlists: playlists,
          songs: [songA, songB],
          audioQuery: _FakeAudioQuery(),
          onChanged: (updated) async {
            playlists = updated;
          },
          onPlay: (_, _, _, _) async {},
        ),
      ),
    );

    await tester.tap(find.text('Mix'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Agregar canciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Track A').last);
    await tester.pumpAndSettle();
    expect(find.text('Esta canción ya pertenece a "Mix".'), findsOneWidget);
    expect(playlists.single.trackPaths, [
      '/music/track-a.flac',
      '/music/track-b.mp3',
    ]);

    final searchField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Buscar en esta playlist',
    );
    await tester.enterText(searchField, 'Track B');
    await tester.pumpAndSettle();
    expect(find.text('Track B'), findsNWidgets(2));
    expect(find.text('Track A'), findsNothing);

    await tester.enterText(searchField, '');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Quitar de la playlist').first);
    await tester.pumpAndSettle();
    expect(playlists.single.trackPaths, ['/music/track-b.mp3']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creates, renames, and deletes a playlist', (tester) async {
    var playlists = <Playlist>[];
    await tester.pumpWidget(
      MaterialApp(
        home: PlaylistLibraryPage(
          playlists: playlists,
          songs: const [],
          audioQuery: OnAudioQuery(),
          onChanged: (updated) async => playlists = updated,
          onPlay: (_, _, _, _) async {},
        ),
      ),
    );

    await tester.tap(find.text('Crear playlist'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Entrenamiento');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Entrenamiento'), findsOneWidget);
    expect(playlists.single.name, 'Entrenamiento');

    await tester.tap(find.byTooltip('Opciones de Entrenamiento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renombrar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Favoritas');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Favoritas'), findsOneWidget);
    expect(playlists.single.name, 'Favoritas');

    await tester.tap(find.byTooltip('Opciones de Favoritas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();
    expect(playlists, isEmpty);
    expect(find.text('Todavía no tienes playlists'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeAudioQuery extends OnAudioQuery {
  @override
  Future<Uint8List?> queryArtwork(
    int id,
    ArtworkType type, {
    ArtworkFormat? format,
    int? size,
    int? quality,
  }) async => null;
}
