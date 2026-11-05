import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reproductor_flac/equalizer_state.dart';
import 'package:reproductor_flac/music_settings_page.dart';

void main() {
  testWidgets('audio settings fit a narrow screen with native EQ bands', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final equalizerState = ValueNotifier(
      const EqualizerState(
        minGain: -15,
        maxGain: 15,
        centerFrequencies: [60, 230, 910, 3600, 14000],
        gains: [3, 2, 0, -2, -1],
      ),
    );
    addTearDown(equalizerState.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MusicSettingsPage(
          themeStyle: 'amoled',
          accentColor: Colors.green,
          refreshRate: 'auto',
          coverStyle: 'standard',
          playerBackgroundStyle: 'gradient',
          equalizerEnabled: true,
          equalizerPreset: 'rock',
          equalizerState: equalizerState,
          smoothTransitionsEnabled: true,
          transitionDurationSeconds: 2,
          preloadQueue: false,
          skipShortTracks: false,
          selectedFolderPath: null,
          onThemeStyleChanged: (_) async {},
          onAccentColorChanged: (_) async {},
          onRefreshRateChanged: (_) async {},
          onCoverStyleChanged: (_) async {},
          onPlayerBackgroundStyleChanged: (_) async {},
          onEqualizerEnabledChanged: (_) async {},
          onEqualizerPresetChanged: (_) async {},
          onEqualizerBandGainChanged: (_, _) async {},
          onSmoothTransitionsEnabledChanged: (_) async {},
          onTransitionDurationChanged: (_) async {},
          onPreloadQueueChanged: (_) async {},
          onSkipShortTracksChanged: (_) async {},
          onSelectFolder: () async {},
          onRescan: () async {},
        ),
      ),
    );

    for (
      var attempt = 0;
      attempt < 4 &&
          find.text('Fundido suave entre canciones').evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pumpAndSettle();
    }

    expect(tester.takeException(), isNull);
    expect(find.text('Fundido suave entre canciones'), findsOneWidget);
    expect(find.text('14 kHz'), findsOneWidget);
  });
}
