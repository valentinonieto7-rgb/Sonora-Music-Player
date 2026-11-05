import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'equalizer_presets.dart';
import 'equalizer_state.dart';
import 'ui_helpers.dart';

class MusicSettingsPage extends StatefulWidget {
  const MusicSettingsPage({
    required this.themeStyle,
    required this.accentColor,
    required this.refreshRate,
    required this.coverStyle,
    required this.playerBackgroundStyle,
    required this.equalizerEnabled,
    required this.equalizerPreset,
    required this.equalizerState,
    required this.smoothTransitionsEnabled,
    required this.transitionDurationSeconds,
    required this.preloadQueue,
    required this.skipShortTracks,
    required this.selectedFolderPath,
    required this.onThemeStyleChanged,
    required this.onAccentColorChanged,
    required this.onRefreshRateChanged,
    required this.onCoverStyleChanged,
    required this.onPlayerBackgroundStyleChanged,
    required this.onEqualizerEnabledChanged,
    required this.onEqualizerPresetChanged,
    required this.onEqualizerBandGainChanged,
    required this.onSmoothTransitionsEnabledChanged,
    required this.onTransitionDurationChanged,
    required this.onPreloadQueueChanged,
    required this.onSkipShortTracksChanged,
    required this.onSelectFolder,
    required this.onRescan,
    super.key,
  });

  final String themeStyle;
  final Color accentColor;
  final String refreshRate;
  final String coverStyle;
  final String playerBackgroundStyle;
  final bool equalizerEnabled;
  final String equalizerPreset;
  final ValueListenable<EqualizerState> equalizerState;
  final bool smoothTransitionsEnabled;
  final int transitionDurationSeconds;
  final bool preloadQueue;
  final bool skipShortTracks;
  final String? selectedFolderPath;
  final Future<void> Function(String style) onThemeStyleChanged;
  final Future<void> Function(Color color) onAccentColorChanged;
  final Future<void> Function(String value) onRefreshRateChanged;
  final Future<void> Function(String style) onCoverStyleChanged;
  final Future<void> Function(String style) onPlayerBackgroundStyleChanged;
  final Future<void> Function(bool enabled) onEqualizerEnabledChanged;
  final Future<void> Function(String preset) onEqualizerPresetChanged;
  final Future<void> Function(int index, double gain)
  onEqualizerBandGainChanged;
  final Future<void> Function(bool enabled) onSmoothTransitionsEnabledChanged;
  final Future<void> Function(int seconds) onTransitionDurationChanged;
  final Future<void> Function(bool enabled) onPreloadQueueChanged;
  final Future<void> Function(bool enabled) onSkipShortTracksChanged;
  final Future<void> Function() onSelectFolder;
  final Future<void> Function() onRescan;

  @override
  State<MusicSettingsPage> createState() => _MusicSettingsPageState();
}

class _MusicSettingsPageState extends State<MusicSettingsPage> {
  static const _accentPalette = [
    Color(0xFF1DB954),
    Color(0xFF42A5F5),
    Color(0xFFE879F9),
    Color(0xFFFF7043),
    Color(0xFFFFCA28),
    Color(0xFF26C6DA),
  ];

  late String _themeStyle = widget.themeStyle;
  late Color _accentColor = widget.accentColor;
  late String _refreshRate = widget.refreshRate;
  late String _coverStyle = widget.coverStyle;
  late String _playerBackgroundStyle = widget.playerBackgroundStyle;
  late bool _equalizerEnabled = widget.equalizerEnabled;
  late String _equalizerPreset = widget.equalizerPreset;
  late bool _smoothTransitionsEnabled = widget.smoothTransitionsEnabled;
  late int _transitionDurationSeconds = widget.transitionDurationSeconds;
  late bool _preloadQueue = widget.preloadQueue;
  late bool _skipShortTracks = widget.skipShortTracks;

  Future<void> _changeTheme(String value) async {
    setState(() => _themeStyle = value);
    await widget.onThemeStyleChanged(value);
  }

  Future<void> _changeAccent(Color color) async {
    setState(() => _accentColor = color);
    await widget.onAccentColorChanged(color);
  }

  Future<void> _changeRefreshRate(String value) async {
    setState(() => _refreshRate = value);
    await widget.onRefreshRateChanged(value);
  }

  Future<void> _changeCoverStyle(String value) async {
    setState(() => _coverStyle = value);
    await widget.onCoverStyleChanged(value);
  }

  Future<void> _changePlayerBackgroundStyle(String value) async {
    setState(() => _playerBackgroundStyle = value);
    await widget.onPlayerBackgroundStyleChanged(value);
  }

  Future<void> _changeEqualizerEnabled(bool enabled) async {
    setState(() => _equalizerEnabled = enabled);
    await widget.onEqualizerEnabledChanged(enabled);
  }

  Future<void> _changeEqualizerPreset(String preset) async {
    setState(() => _equalizerPreset = preset);
    await widget.onEqualizerPresetChanged(preset);
  }

  Future<void> _changeEqualizerBandGain(int index, double gain) async {
    setState(() => _equalizerPreset = 'custom');
    await widget.onEqualizerBandGainChanged(index, gain);
  }

  Future<void> _changeSmoothTransitions(bool enabled) async {
    setState(() => _smoothTransitionsEnabled = enabled);
    await widget.onSmoothTransitionsEnabledChanged(enabled);
  }

  Future<void> _changeTransitionDuration(int seconds) async {
    setState(() => _transitionDurationSeconds = seconds);
    await widget.onTransitionDurationChanged(seconds);
  }

  Future<void> _changePreload(bool enabled) async {
    setState(() => _preloadQueue = enabled);
    await widget.onPreloadQueueChanged(enabled);
  }

  Future<void> _changeSkipShortTracks(bool enabled) async {
    setState(() => _skipShortTracks = enabled);
    await widget.onSkipShortTracksChanged(enabled);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _SettingsSection(
            icon: Icons.palette_outlined,
            title: 'APARIENCIA',
            children: [
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Tema'),
                subtitle: Text(
                  'El negro puro ayuda a ahorrar batería en AMOLED',
                ),
              ),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'amoled',
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('AMOLED'),
                  ),
                  ButtonSegment(
                    value: 'dark',
                    icon: Icon(Icons.brightness_2_outlined),
                    label: Text('Oscuro'),
                  ),
                  ButtonSegment(
                    value: 'light',
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Claro'),
                  ),
                ],
                selected: {_themeStyle},
                onSelectionChanged: (value) => _changeTheme(value.first),
              ),
              const SizedBox(height: 18),
              const Text(
                'Color de acento',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                children: [
                  for (final color in _accentPalette)
                    Semantics(
                      label: 'Color de acento',
                      selected: color.toARGB32() == _accentColor.toARGB32(),
                      child: InkWell(
                        onTap: () => _changeAccent(color),
                        customBorder: const CircleBorder(),
                        child: CircleAvatar(
                          radius: 19,
                          backgroundColor: color,
                          child: color.toARGB32() == _accentColor.toARGB32()
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.black,
                                  size: 20,
                                )
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Tamaño de carátulas en listas',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'standard', label: Text('Estándar')),
                  ButtonSegment(value: 'compact', label: Text('Compacto')),
                ],
                selected: {_coverStyle},
                onSelectionChanged: (value) => _changeCoverStyle(value.first),
              ),
            ],
          ),
          _SettingsSection(
            icon: Icons.album_outlined,
            title: 'EN REPRODUCCIÓN',
            children: [
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Fondo del reproductor'),
                subtitle: Text(
                  'Elige un estilo más visible para la pantalla de reproducción',
                ),
              ),
              SizedBox(
                height: 174,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _PlayerBackgroundOption(
                      style: 'blurred',
                      label: 'Desenfocado',
                      selected: _playerBackgroundStyle == 'blurred',
                      accentColor: _accentColor,
                      onTap: () => _changePlayerBackgroundStyle('blurred'),
                    ),
                    _PlayerBackgroundOption(
                      style: 'gradient',
                      label: 'Degradado',
                      selected: _playerBackgroundStyle == 'gradient',
                      accentColor: _accentColor,
                      onTap: () => _changePlayerBackgroundStyle('gradient'),
                    ),
                    _PlayerBackgroundOption(
                      style: 'accent',
                      label: 'Color de acento',
                      selected: _playerBackgroundStyle == 'accent',
                      accentColor: _accentColor,
                      onTap: () => _changePlayerBackgroundStyle('accent'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _SettingsSection(
            icon: Icons.graphic_eq_rounded,
            title: 'REPRODUCCIÓN',
            children: [
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Frecuencia de pantalla'),
                subtitle: Text(
                  'Android y el modo de ahorro pueden limitar la frecuencia efectiva',
                ),
              ),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'auto', label: Text('Auto')),
                  ButtonSegment(value: '60', label: Text('60 Hz')),
                  ButtonSegment(value: '120', label: Text('120 Hz')),
                ],
                selected: {_refreshRate},
                onSelectionChanged: (value) => _changeRefreshRate(value.first),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Precargar la cola'),
                subtitle: const Text(
                  'Puede reducir pausas entre pistas compatibles, pero prepara más elementos y usa más memoria.',
                ),
                value: _preloadQueue,
                activeTrackColor: theme.colorScheme.primary,
                onChanged: _changePreload,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'El audio se decodifica con el motor nativo de Android. La reproducción sin huecos depende del códec y del archivo; el búfer lo gestiona ExoPlayer/just_audio.',
                  style: TextStyle(
                    color: secondaryTextColor(context),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          _SettingsSection(
            icon: Icons.equalizer_rounded,
            title: 'AUDIO',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ecualizador nativo'),
                subtitle: const Text(
                  'Ajusta el sonido con el ecualizador de Android',
                ),
                value: _equalizerEnabled,
                activeTrackColor: theme.colorScheme.primary,
                onChanged: _changeEqualizerEnabled,
              ),
              DropdownButtonFormField<String>(
                initialValue: _equalizerPreset == 'custom'
                    ? null
                    : _equalizerPreset,
                hint: const Text('Personalizado'),
                decoration: const InputDecoration(
                  labelText: 'Preajuste',
                  border: OutlineInputBorder(),
                ),
                items: equalizerPresets.entries
                    .where((entry) => entry.key != 'custom')
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (preset) {
                  if (preset != null) _changeEqualizerPreset(preset);
                },
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<EqualizerState>(
                valueListenable: widget.equalizerState,
                builder: (context, state, _) {
                  if (state.error != null) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        state.error!,
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }
                  if (!state.isAvailable) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Inicia una canción para detectar las bandas disponibles.',
                        style: TextStyle(
                          color: secondaryTextColor(context),
                          fontSize: 12,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (
                        var index = 0;
                        index < state.centerFrequencies.length;
                        index++
                      )
                        _EqualizerBandSlider(
                          frequency: state.centerFrequencies[index],
                          gain: state.gains[index],
                          minGain: state.minGain,
                          maxGain: state.maxGain,
                          enabled: _equalizerEnabled,
                          onChanged: (gain) =>
                              _changeEqualizerBandGain(index, gain),
                        ),
                    ],
                  );
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fundido suave entre canciones'),
                subtitle: const Text(
                  'Baja y recupera el volumen al cambiar de pista. No superpone canciones.',
                ),
                value: _smoothTransitionsEnabled,
                activeTrackColor: theme.colorScheme.primary,
                onChanged: _changeSmoothTransitions,
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'La cola de just_audio conserva el avance gapless; el fundido es una rampa de volumen con un solo reproductor.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const Text(
                'Duración del fundido',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final seconds in [1, 2, 3, 5])
                    ChoiceChip(
                      label: Text('$seconds s'),
                      selected: _transitionDurationSeconds == seconds,
                      onSelected: (_) => _changeTransitionDuration(seconds),
                    ),
                ],
              ),
            ],
          ),
          _SettingsSection(
            icon: Icons.library_music_outlined,
            title: 'CONTENIDO',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.folder_open_rounded),
                title: Text(
                  widget.selectedFolderPath == null
                      ? 'Elegir carpeta de música'
                      : 'Carpeta seleccionada',
                ),
                subtitle: widget.selectedFolderPath == null
                    ? const Text('FLAC, MP3 y audio en MP4/M4A')
                    : Text(
                        widget.selectedFolderPath!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                onTap: widget.onSelectFolder,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Omitir pistas menores a 30 segundos'),
                subtitle: const Text(
                  'Filtra tonos y notas de voz cortas de la biblioteca',
                ),
                value: _skipShortTracks,
                activeTrackColor: theme.colorScheme.primary,
                onChanged: _changeSkipShortTracks,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.refresh_rounded),
                title: const Text('Volver a escanear'),
                subtitle: const Text('Actualizar canciones de la carpeta'),
                onTap: widget.onRescan,
              ),
            ],
          ),
          _SettingsSection(
            icon: Icons.info_outline_rounded,
            title: 'APLICACIÓN',
            children: const [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Sonora'),
                subtitle: Text('Versión 1.0.0 · Flutter · just_audio'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Creado por'),
                subtitle: Text('Valentino Nieto'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EqualizerBandSlider extends StatelessWidget {
  const _EqualizerBandSlider({
    required this.frequency,
    required this.gain,
    required this.minGain,
    required this.maxGain,
    required this.enabled,
    required this.onChanged,
  });

  final double frequency;
  final double gain;
  final double minGain;
  final double maxGain;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = frequency >= 1000
        ? '${(frequency / 1000).toStringAsFixed(frequency >= 10000 ? 0 : 1)} kHz'
        : '${frequency.round()} Hz';
    return Column(
      children: [
        Row(
          children: [
            SizedBox(width: 56, child: Text(label)),
            Expanded(
              child: Slider(
                value: gain.clamp(minGain, maxGain),
                min: minGain,
                max: maxGain,
                divisions: ((maxGain - minGain) * 2).round().clamp(1, 200),
                label: '${gain.toStringAsFixed(1)} dB',
                onChanged: enabled ? onChanged : null,
              ),
            ),
            SizedBox(
              width: 52,
              child: Text(
                '${gain.toStringAsFixed(1)} dB',
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlayerBackgroundOption extends StatelessWidget {
  const _PlayerBackgroundOption({
    required this.style,
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  final String style;
  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final alternateColor = HSLColor.fromColor(accentColor)
        .withHue((HSLColor.fromColor(accentColor).hue + 42) % 360)
        .toColor();
    final previewColors = switch (style) {
      'gradient' => [
        accentColor.withValues(alpha: 0.95),
        alternateColor.withValues(alpha: 0.8),
        const Color(0xFF171923),
      ],
      'accent' => [
        accentColor,
        Color.lerp(accentColor, Colors.black, 0.45)!,
        Colors.black,
      ],
      _ => [
        const Color(0xFF9C5863),
        const Color(0xFF4A3038),
        const Color(0xFF171923),
      ],
    };

    return Semantics(
      button: true,
      selected: selected,
      label: 'Fondo del reproductor: $label',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 108,
          margin: const EdgeInsets.only(right: 12, bottom: 4),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 132,
                width: 88,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: 2,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: previewColors,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(left: 8, bottom: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      width: 30,
                      height: 3,
                      margin: const EdgeInsets.only(left: 8, bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                    const SizedBox(height: 10),
                    const Center(
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 7),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}
