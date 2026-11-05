import 'dart:math';

import 'package:flutter/material.dart';

class MarqueeText extends StatefulWidget {
  const MarqueeText(this.text, {required this.style, super.key});

  final String text;
  final TextStyle style;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );
  double _overflowDistance = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          textDirection: Directionality.of(context),
          maxLines: 1,
        )..layout();
        final overflow = max(0.0, painter.width - constraints.maxWidth);
        if ((_overflowDistance - overflow).abs() > 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || (_overflowDistance - overflow).abs() <= 1) return;
            setState(() {
              _overflowDistance = overflow;
            });
            if (overflow > 0) {
              _controller.repeat(reverse: true);
            } else {
              _controller
                ..stop()
                ..value = 0;
            }
          });
        }

        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.translate(
              offset: Offset(-_overflowDistance * _controller.value, 0),
              child: child,
            ),
            child: SizedBox(
              width: max(painter.width, constraints.maxWidth),
              child: Text(
                widget.text,
                style: widget.style,
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
        );
      },
    );
  }
}
