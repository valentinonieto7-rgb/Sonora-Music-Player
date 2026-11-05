import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import 'ui_helpers.dart';

class CachedArtwork extends StatefulWidget {
  const CachedArtwork({
    required this.controller,
    required this.id,
    required this.width,
    required this.height,
    required this.borderRadius,
    super.key,
  });

  final OnAudioQuery controller;
  final int id;
  final double width;
  final double height;
  final BorderRadius borderRadius;

  @override
  State<CachedArtwork> createState() => _CachedArtworkState();
}

class _CachedArtworkState extends State<CachedArtwork> {
  static const _maxCachedArtworks = 32;
  static final LinkedHashMap<int, Uint8List> _artworkCache =
      LinkedHashMap<int, Uint8List>();

  late Future<Uint8List?> _artworkFuture;

  @override
  void initState() {
    super.initState();
    _artworkFuture = _loadArtwork();
  }

  @override
  void didUpdateWidget(covariant CachedArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id ||
        oldWidget.controller != widget.controller) {
      _artworkFuture = _loadArtwork();
    }
  }

  Future<Uint8List?> _loadArtwork() {
    final cachedArtwork = _artworkCache.remove(widget.id);
    if (cachedArtwork != null) {
      _artworkCache[widget.id] = cachedArtwork;
      return Future.value(cachedArtwork);
    }

    return widget.controller
        .queryArtwork(widget.id, ArtworkType.AUDIO, quality: 100, size: 600)
        .then(
          (artwork) {
            if (artwork != null) {
              _artworkCache[widget.id] = artwork;
              if (_artworkCache.length > _maxCachedArtworks) {
                _artworkCache.remove(_artworkCache.keys.first);
              }
            }
            return artwork;
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('No se pudo cargar la carátula ${widget.id}: $error');
            Error.throwWithStackTrace(error, stackTrace);
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = ArtworkPlaceholder(
      size: min(widget.width, widget.height),
    );
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: FutureBuilder<Uint8List?>(
          future: _artworkFuture,
          builder: (context, snapshot) {
            final artwork = snapshot.data;
            if (artwork == null) return placeholder;
            return Image.memory(
              artwork,
              width: widget.width,
              height: widget.height,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('No se pudo renderizar la carátula: $error');
                return placeholder;
              },
            );
          },
        ),
      ),
    );
  }
}

class ArtworkPlaceholder extends StatelessWidget {
  const ArtworkPlaceholder({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFF263329),
      child: Icon(
        Icons.music_note_rounded,
        color: const Color(0xFF1DB954),
        size: size * 0.48,
      ),
    );
  }
}

class MessageState extends StatelessWidget {
  const MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(compact ? 4 : 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: compact ? 24 : 48,
                    color: const Color(0xFF1DB954),
                  ),
                  SizedBox(height: compact ? 4 : 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: compact ? 16 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: compact ? 2 : 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: secondaryTextColor(context),
                      height: 1.4,
                    ),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    SizedBox(height: compact ? 10 : 18),
                    FilledButton(
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
