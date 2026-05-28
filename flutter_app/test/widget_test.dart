// This is a basic Flutter widget test for the ZK Rollup Wallet.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zk_wallet/main.dart';

void main() {
  testWidgets('Dashboard smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the Dashboard screen is loaded and displays the address selection card.
    expect(find.text('Select Wallet Address'), findsOneWidget);
  });
}
