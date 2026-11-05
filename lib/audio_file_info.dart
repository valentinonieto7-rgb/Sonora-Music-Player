import 'dart:io';

class AudioFileInfo {
  const AudioFileInfo({
    required this.format,
    required this.averageBitrateKbps,
    required this.sampleRateHz,
  });

  final String format;
  final int? averageBitrateKbps;
  final int? sampleRateHz;

  String get label => [
    format,
    if (averageBitrateKbps != null) '~${averageBitrateKbps!} kb/s',
    if (sampleRateHz != null)
      '${(sampleRateHz! / 1000).toStringAsFixed(1)} kHz',
  ].join('  ·  ');
}

bool isSupportedAudioPath(String path) {
  final extension = _fileExtension(path);
  return const {'.flac', '.mp3', '.mp4', '.m4a'}.contains(extension);
}

Future<AudioFileInfo> readAudioFileInfo(String path, int? durationMs) async {
  final file = File(path);
  final format = switch (_fileExtension(path)) {
    '.flac' => 'FLAC',
    '.mp3' => 'MP3',
    '.mp4' => 'MP4',
    '.m4a' => 'M4A',
    _ => 'Audio',
  };
  final durationSeconds = (durationMs ?? 0) / 1000;
  final averageBitrate = durationSeconds > 0
      ? ((await file.length() * 8) / durationSeconds / 1000).round()
      : 0;
  final bitrate = averageBitrate > 0 ? averageBitrate : null;
  final handle = await file.open();
  try {
    final bytes = await handle.read(256 * 1024);
    final sampleRate = switch (format) {
      'FLAC' => _flacSampleRate(bytes),
      'MP3' => _mp3SampleRate(bytes),
      _ => null,
    };
    return AudioFileInfo(
      format: format,
      averageBitrateKbps: bitrate,
      sampleRateHz: sampleRate,
    );
  } finally {
    await handle.close();
  }
}

String _fileExtension(String path) {
  final separator = path.lastIndexOf('.');
  return separator < 0 ? '' : path.substring(separator).toLowerCase();
}

int? _flacSampleRate(List<int> bytes) {
  if (bytes.length < 8 ||
      bytes[0] != 0x66 ||
      bytes[1] != 0x4C ||
      bytes[2] != 0x61 ||
      bytes[3] != 0x43) {
    return null;
  }
  var offset = 4;
  while (offset + 4 <= bytes.length) {
    final type = bytes[offset] & 0x7F;
    final length =
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
    final payload = offset + 4;
    if (type == 0 && length >= 18 && payload + 18 <= bytes.length) {
      return (bytes[payload + 10] << 12) |
          (bytes[payload + 11] << 4) |
          (bytes[payload + 12] >> 4);
    }
    if ((bytes[offset] & 0x80) != 0 || payload + length > bytes.length) {
      break;
    }
    offset = payload + length;
  }
  return null;
}

int? _mp3SampleRate(List<int> bytes) {
  var start = 0;
  if (bytes.length >= 10 &&
      bytes[0] == 0x49 &&
      bytes[1] == 0x44 &&
      bytes[2] == 0x33) {
    final tagSize =
        (bytes[6] << 21) | (bytes[7] << 14) | (bytes[8] << 7) | bytes[9];
    start = 10 + tagSize;
  }

  for (var index = start; index + 4 <= bytes.length; index++) {
    final header =
        (bytes[index] << 24) |
        (bytes[index + 1] << 16) |
        (bytes[index + 2] << 8) |
        bytes[index + 3];
    if ((header & 0xFFE00000) != 0xFFE00000) continue;

    final version = (header >> 19) & 0x3;
    final layer = (header >> 17) & 0x3;
    final sampleIndex = (header >> 10) & 0x3;
    if (version == 1 || layer != 1 || sampleIndex == 3) continue;
    const sampleRates = [44100, 48000, 32000];
    final divisor = version == 3
        ? 1
        : version == 2
        ? 2
        : 4;
    return sampleRates[sampleIndex] ~/ divisor;
  }
  return null;
}
