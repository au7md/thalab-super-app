// Regression test: opening the media viewer with an empty asset list used to
// crash in initState (int.clamp(0, -1) throws ArgumentError) before the empty
// guard in build() could render.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thalab_app/features/media/media_viewer_screen.dart';

void main() {
  testWidgets('media viewer handles an empty asset list without crashing',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(
      home: MediaViewerScreen(assets: [], initialIndex: 0),
    ));
    await tester.pump();
    expect(find.byType(Scaffold), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
