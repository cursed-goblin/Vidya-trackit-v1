// Smoke test for the app shell.
//
// The old test came from the `flutter create` counter template and referenced
// a `MyApp` class that never existed in this project. It checks that the root
// widget builds and lands on the role picker without throwing.
//
// Note: main() is not called here, so Supabase and Firebase are never
// initialised. Only widgets that tolerate a missing backend can be tested this
// way - RoleSelectScreen does, because it just offers three buttons.

import 'package:flutter_test/flutter_test.dart';

import 'package:vidya_trackit/main.dart';

void main() {
  testWidgets('app builds and shows the role picker',
      (WidgetTester tester) async {
    await tester.pumpWidget(const VidyaTrackItApp());
    await tester.pump();

    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Teacher'), findsOneWidget);
    expect(find.text('Driver'), findsOneWidget);
  });
}
