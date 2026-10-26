import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikaddis/core/theme.dart';
import 'package:tikaddis/widgets/delete_account_dialog.dart';

Future<void> openDialog(
  WidgetTester tester,
  Future<void> Function(String) onDelete,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<bool>(
              context: context,
              builder: (_) => DeleteAccountDialog(onDelete: onDelete),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Deletion requires acknowledgement and a current password', (
    tester,
  ) async {
    var calls = 0;
    String? password;
    await openDialog(tester, (value) async {
      calls++;
      password = value;
    });
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Delete account'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your current password'), findsOneWidget);
    expect(calls, 0);
    await tester.enterText(find.byType(TextFormField), 'MyCurrentPassword');
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(password, 'MyCurrentPassword');
    expect(find.byType(DeleteAccountDialog), findsNothing);
  });

  testWidgets('An incorrect password leaves the dialog open with an error', (
    tester,
  ) async {
    await openDialog(tester, (_) async {
      throw DioException(
        requestOptions: RequestOptions(path: '/account/me'),
        response: Response(
          requestOptions: RequestOptions(path: '/account/me'),
          statusCode: 403,
        ),
      );
    });
    await tester.enterText(find.byType(TextFormField), 'wrong');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('Your current password is incorrect.'), findsOneWidget);
    expect(find.byType(DeleteAccountDialog), findsOneWidget);
  });

  testWidgets('Cancel never submits a deletion request', (tester) async {
    var called = false;
    await openDialog(tester, (_) async {
      called = true;
    });
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(called, isFalse);
    expect(find.byType(DeleteAccountDialog), findsNothing);
  });
}
