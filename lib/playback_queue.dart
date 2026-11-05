class PlaybackQueue {
  const PlaybackQueue._();

  static List<T>? insertNext<T>(
    List<T> queue,
    T item, {
    required String Function(T item) pathOf,
    required String? currentPath,
  }) {
    final itemPath = pathOf(item);
    if (itemPath == currentPath) return null;
    final updated = queue.where((entry) => pathOf(entry) != itemPath).toList();
    final currentIndex = currentPath == null
        ? -1
        : updated.indexWhere((entry) => pathOf(entry) == currentPath);
    updated.insert(currentIndex + 1, item);
    return updated;
  }

  static List<T> reorder<T>(List<T> queue, int oldIndex, int newIndex) {
    final updated = List<T>.of(queue);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    return updated;
  }

  static List<T> removeAt<T>(List<T> queue, int index) {
    final updated = List<T>.of(queue)..removeAt(index);
    return updated;
  }
}
