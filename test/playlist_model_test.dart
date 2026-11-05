import 'package:flutter_test/flutter_test.dart';
import 'package:reproductor_flac/playlist_model.dart';

void main() {
  test('playlist preserves ordered track paths when serialized', () {
    const playlist = Playlist(
      id: 'favorites-mix',
      name: 'Mi mezcla',
      trackPaths: ['/music/one.flac', '/music/two.mp3'],
    );

    expect(
      Playlist.fromJson(playlist.toJson()).trackPaths,
      playlist.trackPaths,
    );
  });

  test('playlist restore removes malformed and duplicate track paths', () {
    final playlist = Playlist.fromJson({
      'id': 'road-trip',
      'name': 'Viaje',
      'trackPaths': ['/music/one.flac', 3, '', '/music/one.flac'],
    });

    expect(playlist.trackPaths, ['/music/one.flac']);
  });

  test('playlist rejects duplicate tracks and preserves manual reordering', () {
    const playlist = Playlist(
      id: 'mix',
      name: 'Mezcla',
      trackPaths: ['/music/one.flac', '/music/two.mp3'],
    );

    expect(playlist.addTrack('/music/one.flac'), isNull);
    expect(
      playlist.reorderTrack(0, 1).trackPaths,
      ['/music/two.mp3', '/music/one.flac'],
    );
    expect(playlist.removeTrack('/music/one.flac').trackPaths, [
      '/music/two.mp3',
    ]);
  });
}
