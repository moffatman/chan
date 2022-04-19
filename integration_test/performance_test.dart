import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("failing test example", (WidgetTester tester) async {
  	final Finder settingsIcon = find.byIcon(CupertinoIcons.settings);
		expect(settingsIcon, findsNothing);
		//expect(settingsIcon, findsOneWidget);
		//await tester.tap(settingsIcon);
  });
}