import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iptv_app/main.dart';

void main() {
  testWidgets('App falls back to the Xtream login screen with no saved credentials',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});

    await tester.pumpWidget(const IptvApp());
    await tester.pumpAndSettle();

    expect(find.text('Sign in with your Xtream Codes account'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
  });

  testWidgets('Login screen can switch to M3U playlist mode', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});

    await tester.pumpWidget(const IptvApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('M3U link'));
    await tester.pumpAndSettle();

    expect(find.text('Load your M3U playlist link'), findsOneWidget);
    expect(find.text('Playlist link'), findsOneWidget);
    expect(find.text('Username'), findsNothing);
  });
}
