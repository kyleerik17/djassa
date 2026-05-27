import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djassa/presentation/widgets/buttons/djassa_button.dart';

void main() {
  testWidgets('DjassaButton displays its label and handles taps', (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DjassaButton(
            text: 'Se connecter',
            onPressed: () => tapCount++,
          ),
        ),
      ),
    );

    expect(find.text('Se connecter'), findsOneWidget);

    await tester.tap(find.text('Se connecter'));
    await tester.pump();

    expect(tapCount, 1);
  });
}
