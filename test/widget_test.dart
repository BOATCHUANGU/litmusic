import 'package:flutter_test/flutter_test.dart';
import 'package:litmusic/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LitMusicApp());
    // App should render the WelcomePage
    expect(find.text('LitMusic'), findsOneWidget);
  });
}
