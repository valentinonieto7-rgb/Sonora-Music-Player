import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reproductor_flac/artwork_widgets.dart';

void main() {
  testWidgets('empty-state message adapts to a short viewport', (tester) async {
    tester.view.physicalSize = const Size(360, 240);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 100,
            child: MessageState(
              icon: Icons.album_outlined,
              title: 'No hay álbumes',
              message: 'Selecciona una carpeta que contenga música.',
              actionLabel: 'Seleccionar carpeta',
              onAction: () {},
              compact: true,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
