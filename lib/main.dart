import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'equalizer_presets.dart';
import 'music_home_page.dart';

const _displayChannel = MethodChannel('com.example.reproductor_flac/display');
const _playerBackgroundStyles = {'blurred', 'gradient', 'accent'};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.reproductor_flac.audio',
    androidNotificationChannelName: 'Reproducción de música',
    androidNotificationChannelDescription: 'Controles de Sonora FLAC',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
    artDownscaleWidth: 500,
    artDownscaleHeight: 500,
  );
  runApp(const FlacPlayerApp());
}

class FlacPlayerApp extends StatefulWidget {
  const FlacPlayerApp({super.key});

  @override
  State<FlacPlayerApp> createState() => _FlacPlayerAppState();
}

class _FlacPlayerAppState extends State<FlacPlayerApp> {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  String _themeStyle = 'amoled';
  int _accentColorValue = 0xFF1DB954;
  String _refreshRate = 'auto';
  String _coverStyle = 'standard';
  String _playerBackgroundStyle = 'gradient';
  bool _equalizerEnabled = false;
  String _equalizerPreset = 'flat';
  List<double> _equalizerBandGains = const [];
  bool _smoothTransitionsEnabled = false;
  int _transitionDurationSeconds = 2;
  bool _preloadQueue = false;
  bool _skipShortTracks = false;

  bool get _amoledMode => _themeStyle == 'amoled';

  Future<void> _savePreference(Future<void> Function() save) async {
    try {
      await save();
    } catch (error) {
      debugPrint('No se pudo guardar una preferencia: $error');
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    try {
      final amoled = await _preferences.getBool('amoled_mode');
      final themeStyle = await _preferences.getString('theme_style');
      final accentColor = await _preferences.getInt('accent_color');
      final refreshRate = await _preferences.getString('refresh_rate');
      final coverStyle = await _preferences.getString('cover_style');
      final playerBackgroundStyle = await _preferences.getString(
        'player_background_style',
      );
      final preloadQueue = await _preferences.getBool('preload_queue');
      final skipShortTracks = await _preferences.getBool('skip_short_tracks');
      final equalizerEnabled = await _preferences.getBool('equalizer_enabled');
      final equalizerPreset = await _preferences.getString('equalizer_preset');
      final equalizerBandGains = await _preferences.getStringList(
        'equalizer_band_gains',
      );
      final smoothTransitionsEnabled = await _preferences.getBool(
        'smooth_transitions_enabled',
      );
      final transitionDurationSeconds = await _preferences.getInt(
        'transition_duration_seconds',
      );
      if (!mounted) return;
      setState(() {
        _themeStyle = themeStyle ?? ((amoled ?? true) ? 'amoled' : 'dark');
        _accentColorValue = accentColor ?? 0xFF1DB954;
        _refreshRate = refreshRate ?? 'auto';
        _coverStyle = coverStyle ?? 'standard';
        _playerBackgroundStyle =
            _playerBackgroundStyles.contains(playerBackgroundStyle)
            ? playerBackgroundStyle!
            : 'gradient';
        _preloadQueue = preloadQueue ?? false;
        _skipShortTracks = skipShortTracks ?? false;
        _equalizerEnabled = equalizerEnabled ?? false;
        _equalizerPreset = equalizerPresets.containsKey(equalizerPreset)
            ? equalizerPreset!
            : 'flat';
        _equalizerBandGains = (equalizerBandGains ?? [])
            .map(double.tryParse)
            .whereType<double>()
            .toList();
        _smoothTransitionsEnabled = smoothTransitionsEnabled ?? false;
        _transitionDurationSeconds =
            const {1, 2, 3, 5}.contains(transitionDurationSeconds)
            ? transitionDurationSeconds!
            : 2;
      });
      await _applyRefreshRate(_refreshRate);
    } catch (error) {
      debugPrint('No se pudieron cargar los ajustes: $error');
    }
  }

  Future<void> _setThemeStyle(String style) async {
    if (!{'amoled', 'dark', 'light'}.contains(style)) return;
    setState(() {
      _themeStyle = style;
    });
    await _savePreference(() => _preferences.setString('theme_style', style));
    await _savePreference(
      () => _preferences.setBool('amoled_mode', style == 'amoled'),
    );
  }

  Future<void> _setAccentColor(Color color) async {
    final value = color.toARGB32();
    setState(() {
      _accentColorValue = value;
    });
    await _savePreference(() => _preferences.setInt('accent_color', value));
  }

  Future<void> _setCoverStyle(String style) async {
    setState(() {
      _coverStyle = style;
    });
    await _savePreference(() => _preferences.setString('cover_style', style));
  }

  Future<void> _setPlayerBackgroundStyle(String style) async {
    if (!_playerBackgroundStyles.contains(style)) return;
    setState(() {
      _playerBackgroundStyle = style;
    });
    await _savePreference(
      () => _preferences.setString('player_background_style', style),
    );
  }

  Future<void> _setEqualizerEnabled(bool enabled) async {
    setState(() => _equalizerEnabled = enabled);
    await _savePreference(
      () => _preferences.setBool('equalizer_enabled', enabled),
    );
  }

  Future<void> _setEqualizerPreset(String preset) async {
    if (!equalizerPresets.containsKey(preset)) return;
    setState(() {
      _equalizerPreset = preset;
      if (preset != 'custom') _equalizerBandGains = const [];
    });
    await _savePreference(
      () => _preferences.setString('equalizer_preset', preset),
    );
    if (preset != 'custom') {
      await _savePreference(
        () => _preferences.setStringList('equalizer_band_gains', const []),
      );
    }
  }

  Future<void> _setEqualizerBandGains(List<double> gains) async {
    setState(() => _equalizerBandGains = List.unmodifiable(gains));
    await _savePreference(
      () => _preferences.setStringList(
        'equalizer_band_gains',
        gains.map((gain) => gain.toString()).toList(),
      ),
    );
  }

  Future<void> _setSmoothTransitionsEnabled(bool enabled) async {
    setState(() => _smoothTransitionsEnabled = enabled);
    await _savePreference(
      () => _preferences.setBool('smooth_transitions_enabled', enabled),
    );
  }

  Future<void> _setTransitionDuration(int seconds) async {
    if (!const {1, 2, 3, 5}.contains(seconds)) return;
    setState(() => _transitionDurationSeconds = seconds);
    await _savePreference(
      () => _preferences.setInt('transition_duration_seconds', seconds),
    );
  }

  Future<void> _setPreloadQueue(bool enabled) async {
    setState(() {
      _preloadQueue = enabled;
    });
    await _savePreference(() => _preferences.setBool('preload_queue', enabled));
  }

  Future<void> _setSkipShortTracks(bool enabled) async {
    setState(() {
      _skipShortTracks = enabled;
    });
    await _savePreference(
      () => _preferences.setBool('skip_short_tracks', enabled),
    );
  }

  Future<void> _setRefreshRate(String value) async {
    await _applyRefreshRate(value);
    if (!mounted) return;
    setState(() {
      _refreshRate = value;
    });
    try {
      await _preferences.setString('refresh_rate', value);
    } catch (error) {
      debugPrint('No se pudo guardar la frecuencia de pantalla: $error');
    }
  }

  Future<void> _applyRefreshRate(String value) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final rate = switch (value) {
      '60' => 60.0,
      '120' => 120.0,
      _ => 0.0,
    };
    try {
      await _displayChannel.invokeMethod<void>('setRefreshRate', rate);
    } on PlatformException catch (error) {
      debugPrint(
        'No se pudo solicitar la frecuencia $value Hz: ${error.message}',
      );
    } on MissingPluginException catch (error) {
      debugPrint('Ajuste de frecuencia no disponible: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Color(_accentColorValue);
    final isLight = _themeStyle == 'light';
    final background = _amoledMode
        ? Colors.black
        : isLight
        ? const Color(0xFFF6F6F6)
        : const Color(0xFF101210);

    return MaterialApp(
      title: 'Sonora',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: isLight ? Brightness.light : Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: isLight ? Brightness.light : Brightness.dark,
          surface: _amoledMode
              ? Colors.black
              : isLight
              ? Colors.white
              : const Color(0xFF191C19),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: background,
          surfaceTintColor: Colors.transparent,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: background,
        ),
        useMaterial3: true,
      ),
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: background,
          statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: background,
          systemNavigationBarIconBrightness: isLight
              ? Brightness.dark
              : Brightness.light,
        ),
        child: child!,
      ),
      home: MusicHomePage(
        amoledMode: _amoledMode,
        themeStyle: _themeStyle,
        accentColor: accent,
        refreshRate: _refreshRate,
        coverStyle: _coverStyle,
        playerBackgroundStyle: _playerBackgroundStyle,
        equalizerEnabled: _equalizerEnabled,
        equalizerPreset: _equalizerPreset,
        equalizerBandGains: _equalizerBandGains,
        smoothTransitionsEnabled: _smoothTransitionsEnabled,
        transitionDurationSeconds: _transitionDurationSeconds,
        preloadQueue: _preloadQueue,
        skipShortTracks: _skipShortTracks,
        onThemeStyleChanged: _setThemeStyle,
        onAccentColorChanged: _setAccentColor,
        onRefreshRateChanged: _setRefreshRate,
        onCoverStyleChanged: _setCoverStyle,
        onPlayerBackgroundStyleChanged: _setPlayerBackgroundStyle,
        onEqualizerEnabledChanged: _setEqualizerEnabled,
        onEqualizerPresetChanged: _setEqualizerPreset,
        onEqualizerBandGainsChanged: _setEqualizerBandGains,
        onSmoothTransitionsEnabledChanged: _setSmoothTransitionsEnabled,
        onTransitionDurationChanged: _setTransitionDuration,
        onPreloadQueueChanged: _setPreloadQueue,
        onSkipShortTracksChanged: _setSkipShortTracks,
      ),
    );
  }
}
