class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.trackPaths,
  });

  final String id;
  final String name;
  final List<String> trackPaths;

  Playlist? addTrack(String path) {
    if (path.isEmpty || trackPaths.contains(path)) return null;
    return copyWith(trackPaths: [...trackPaths, path]);
  }

  Playlist removeTrack(String path) =>
      copyWith(trackPaths: trackPaths.where((item) => item != path).toList());

  Playlist reorderTrack(int oldIndex, int newIndex) {
    final paths = List<String>.of(trackPaths);
    final path = paths.removeAt(oldIndex);
    paths.insert(newIndex, path);
    return copyWith(trackPaths: paths);
  }

  Playlist copyWith({String? name, List<String>? trackPaths}) => Playlist(
    id: id,
    name: name ?? this.name,
    trackPaths: trackPaths ?? this.trackPaths,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'trackPaths': trackPaths,
  };

  factory Playlist.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final paths = json['trackPaths'];
    if (id is! String || id.isEmpty || name is! String || paths is! List) {
      throw const FormatException('Datos de playlist incompletos');
    }
    return Playlist(
      id: id,
      name: name,
      trackPaths: paths.whereType<String>().where((path) => path.isNotEmpty).toSet().toList(),
    );
  }
}
