import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iptv_app/main.dart';

void main() {
  testWidgets('App falls back to the Xtream login screen with no saved credentials',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const IptvApp());
    await tester.pumpAndSettle();

    expect(find.text('Sign in with your Xtream Codes account'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
  });
}
