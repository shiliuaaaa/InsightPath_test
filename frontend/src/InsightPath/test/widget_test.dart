import 'package:flutter_test/flutter_test.dart';
import 'package:insight_path/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(loggedIn: false, role: null));
    await tester.pump();
  });
}
