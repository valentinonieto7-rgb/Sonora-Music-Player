import 'package:flutter_test/flutter_test.dart';
import 'package:reproductor_flac/playback_queue.dart';

void main() {
  test('insert next moves an existing song after the current song', () {
    final queue = PlaybackQueue.insertNext(
      ['a', 'b', 'c'],
      'a',
      pathOf: (path) => path,
      currentPath: 'b',
    );

    expect(queue, ['b', 'a', 'c']);
  });

  test('insert next adds to the start when nothing is playing', () {
    final queue = PlaybackQueue.insertNext(
      ['a', 'b'],
      'c',
      pathOf: (path) => path,
      currentPath: null,
    );

    expect(queue, ['c', 'a', 'b']);
  });

  test('insert next does not add the currently playing song again', () {
    expect(
      PlaybackQueue.insertNext(
        ['a', 'b'],
        'a',
        pathOf: (path) => path,
        currentPath: 'a',
      ),
      isNull,
    );
  });

  test('queue reorder and removal preserve the requested order', () {
    expect(PlaybackQueue.reorder(['a', 'b', 'c'], 2, 0), ['c', 'a', 'b']);
    expect(PlaybackQueue.removeAt(['a', 'b', 'c'], 1), ['a', 'c']);
  });

  test('queue edits preserve a large library-sized list', () {
    final queue = List.generate(10000, (index) => '$index');
    final reordered = PlaybackQueue.insertNext(
      queue,
      '9999',
      pathOf: (path) => path,
      currentPath: '5000',
    )!;

    expect(reordered, hasLength(10000));
    expect(reordered[5000], '5000');
    expect(reordered[5001], '9999');
    expect(reordered.last, '9998');
  });
}
