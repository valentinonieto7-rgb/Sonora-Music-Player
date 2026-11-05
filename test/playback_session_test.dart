import 'package:flutter_test/flutter_test.dart';
import 'package:reproductor_flac/playback_session.dart';

void main() {
  test('saved playback session preserves queue, track, position, and playlist', () {
    const session = PlaybackSession(
      queuePaths: ['/music/a.flac', '/music/b.mp3'],
      currentTrackPath: '/music/b.mp3',
      positionMilliseconds: 153000,
      playlistId: 'road-trip',
    );

    final restored = PlaybackSession.fromJson(session.toJson());
    expect(restored.queuePaths, session.queuePaths);
    expect(restored.currentTrackPath, session.currentTrackPath);
    expect(restored.positionMilliseconds, session.positionMilliseconds);
    expect(restored.playlistId, session.playlistId);
  });

  test('saved playback session ignores invalid paths and clamps negative position', () {
    final session = PlaybackSession.fromJson({
      'queuePaths': ['/music/a.flac', 12, ''],
      'currentTrackPath': null,
      'positionMilliseconds': -10,
      'playlistId': null,
    });

    expect(session.queuePaths, ['/music/a.flac']);
    expect(session.positionMilliseconds, 0);
  });
}
