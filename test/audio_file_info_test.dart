import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reproductor_flac/audio_file_info.dart';

void main() {
  test('supports FLAC, MP3 and audio in MP4/M4A files', () {
    expect(isSupportedAudioPath('/music/song.FLAC'), isTrue);
    expect(isSupportedAudioPath('/music/song.mp3'), isTrue);
    expect(isSupportedAudioPath('/music/song.mp4'), isTrue);
    expect(isSupportedAudioPath('/music/song.m4a'), isTrue);
    expect(isSupportedAudioPath('/music/video.mkv'), isFalse);
  });

  test('reads FLAC sample rate and estimates average bitrate', () async {
    final directory = await Directory.systemTemp.createTemp('sonora-flac-');
    addTearDown(() => directory.delete(recursive: true));
    final bytes = List<int>.filled(42000, 0);
    bytes.setRange(0, 4, [0x66, 0x4C, 0x61, 0x43]);
    bytes.setRange(4, 8, [0, 0, 0, 34]);
    bytes[18] = 0x0A;
    bytes[19] = 0xC4;
    bytes[20] = 0x40;
    final file = File.fromUri(directory.uri.resolve('sample.flac'));
    await file.writeAsBytes(bytes);

    final info = await readAudioFileInfo(file.path, 1000);

    expect(info.format, 'FLAC');
    expect(info.sampleRateHz, 44100);
    expect(info.averageBitrateKbps, 336);
  });

  test('reads MP3 sample rate after the frame sync', () async {
    final directory = await Directory.systemTemp.createTemp('sonora-mp3-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File.fromUri(directory.uri.resolve('sample.mp3'));
    await file.writeAsBytes([0xFF, 0xFB, 0x90, 0x64]);

    final info = await readAudioFileInfo(file.path, 1000);

    expect(info.format, 'MP3');
    expect(info.sampleRateHz, 44100);
  });

  test('labels MP4 and M4A containers without guessing sample rate', () async {
    final directory = await Directory.systemTemp.createTemp('sonora-mp4-');
    addTearDown(() => directory.delete(recursive: true));

    for (final extension in ['mp4', 'm4a']) {
      final file = File.fromUri(directory.uri.resolve('sample.$extension'));
      await file.writeAsBytes(List<int>.filled(42000, 0));

      final info = await readAudioFileInfo(file.path, 1000);

      expect(info.format, extension.toUpperCase());
      expect(info.sampleRateHz, isNull);
    }
  });
}
