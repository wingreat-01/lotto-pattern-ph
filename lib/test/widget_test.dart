import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart';

void main() {
  testWidgets('Generate shows combinations; switching game clears them',
      (tester) async {
    await tester.pumpWidget(const LottoApp());

    expect(find.text('Lotto Pattern Generator'), findsOneWidget);
    expect(find.text('#1'), findsNothing);

    await tester.tap(find.text('Generate'));
    await tester.pump();
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('Copy all'), findsOneWidget);

    await tester.tap(find.text('Ultra Lotto 6/58'));
    await tester.pump();
    expect(find.text('#1'), findsNothing);
  });
}
