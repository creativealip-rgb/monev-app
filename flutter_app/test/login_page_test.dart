import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monev_flutter/features/auth/presentation/login_page.dart";

void main() {
  testWidgets("Login page shows core controls", (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginPage(),
        ),
      ),
    );

    expect(find.text("Login Monev"), findsOneWidget);
    expect(find.widgetWithText(TextField, "Email"), findsOneWidget);
    expect(find.widgetWithText(TextField, "Password"), findsOneWidget);
    expect(find.widgetWithText(FilledButton, "Masuk"), findsOneWidget);
  });
}

