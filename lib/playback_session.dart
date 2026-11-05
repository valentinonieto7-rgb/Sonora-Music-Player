class PlaybackSession {
  const PlaybackSession({
    required this.queuePaths,
    required this.currentTrackPath,
    required this.positionMilliseconds,
    required this.playlistId,
  });

  final List<String> queuePaths;
  final String? currentTrackPath;
  final int positionMilliseconds;
  final String? playlistId;

  Map<String, Object?> toJson() => {
    'queuePaths': queuePaths,
    'currentTrackPath': currentTrackPath,
    'positionMilliseconds': positionMilliseconds,
    'playlistId': playlistId,
  };

  factory PlaybackSession.fromJson(Map<String, dynamic> json) {
    final paths = json['queuePaths'];
    final currentTrackPath = json['currentTrackPath'];
    final position = json['positionMilliseconds'];
    final playlistId = json['playlistId'];
    if (paths is! List ||
        (currentTrackPath != null && currentTrackPath is! String) ||
        position is! int ||
        (playlistId != null && playlistId is! String)) {
      throw const FormatException('Datos de reproducción incompletos');
    }
    return PlaybackSession(
      queuePaths: paths
          .whereType<String>()
          .where((path) => path.isNotEmpty)
          .toList(),
      currentTrackPath: currentTrackPath as String?,
      positionMilliseconds: position < 0 ? 0 : position,
      playlistId: playlistId as String?,
    );
  }
}
