import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:reproductor_flac/now_playing_page.dart';
import 'package:reproductor_flac/sleep_timer_state.dart';

void main() {
  testWidgets('sleep timer sheet scrolls on a short screen when active', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final player = AudioPlayer();
    final currentSong = ValueNotifier<SongModel?>(null);
    final sleepTimerState = ValueNotifier<SleepTimerStatus?>(
      const SleepTimerStatus.countdown(Duration(minutes: 45)),
    );
    addTearDown(player.dispose);
    addTearDown(currentSong.dispose);
    addTearDown(sleepTimerState.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: NowPlayingPage(
          currentSong: currentSong,
          audioQuery: OnAudioQuery(),
          audioPlayer: player,
          sleepTimerState: sleepTimerState,
          backgroundStyle: 'gradient',
          accentColor: Colors.green,
          isShuffleEnabled: false,
          isRepeatEnabled: false,
          onPrevious: () async {},
          onNext: () async {},
          onStartSleepTimer: (_) {},
          onCancelSleepTimer: () {},
          onAddToPlaylist: () {},
          onOpenQueue: () {},
          onShuffleChanged: (_) {},
          onRepeatChanged: (_) async {},
          isFavorite: (_) => false,
          onFavoriteChanged: () {},
        ),
      ),
    );

    await tester.tap(find.byTooltip('Temporizador activo: 45:00'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('En 45 minutos'), findsOneWidget);

    await tester.ensureVisible(find.text('Al terminar la canción actual'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Al terminar la canción actual'), findsOneWidget);
  });
}
