import 'package:flutter/material.dart';

Color secondaryTextColor(BuildContext context, [double opacity = 0.6]) =>
    Theme.of(context).colorScheme.onSurface.withValues(alpha: opacity);
