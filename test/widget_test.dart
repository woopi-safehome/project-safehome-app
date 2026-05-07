import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_safehome_app/app.dart';

void main() {
  testWidgets('Home screen renders SafeHome title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: SafeHomeApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('SafeHome'), findsOneWidget);
  });
}
