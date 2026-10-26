import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tikaddis/core/api_service.dart';
import 'package:tikaddis/core/theme.dart';
import 'package:tikaddis/models/models.dart';
import 'package:tikaddis/providers/auth_provider.dart';
import 'package:tikaddis/providers/data_providers.dart';
import 'package:tikaddis/screens/admin/admin_channel_options_screen.dart';
import 'package:tikaddis/screens/influencer/create_account_screen.dart';

class _OptionsApi extends ApiService {
  final categories = <Map<String, dynamic>>[];
  final platforms = <Map<String, dynamic>>[
    {'code': 'YOUTUBE', 'name': 'YouTube', 'displayOrder': 0},
  ];
  bool rejectDelete = false;
  bool failCategories = false;
  int deleteCalls = 0;

  Response<dynamic> response(dynamic data) => Response(
    data: data,
    requestOptions: RequestOptions(path: '/test'),
  );

  @override
  Future<Response> adminGetCategories() async {
    if (failCategories) {
      throw DioException(requestOptions: RequestOptions(path: '/admin/account-category'),
          response: Response(statusCode: 500,
              requestOptions: RequestOptions(path: '/admin/account-category')));
    }
    return response(categories);
  }

  @override
  Future<Response> getPlatforms({bool admin = false}) async =>
      response(platforms);

  @override
  Future<Response> adminCreateCategory(Map<String, dynamic> data) async {
    categories.add({'id': categories.length + 1, ...data});
    return response(categories.last);
  }

  @override
  Future<Response> adminDeleteCategory(int id) async {
    deleteCalls++;
    if (rejectDelete) {
      throw DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          statusCode: 409,
          requestOptions: RequestOptions(path: '/test'),
        ),
      );
    }
    categories.removeWhere((c) => c['id'] == id);
    return response(null);
  }

  @override
  Future<Response> adminSavePlatform(
    Map<String, dynamic> data, {
    String? code,
  }) async {
    platforms.add(data);
    return response(data);
  }
}

Future<void> _open(WidgetTester tester, _OptionsApi api) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [apiServiceProvider.overrideWithValue(api)],
      child: MaterialApp(theme: AppTheme.light,
          home: const AdminChannelOptionsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Options tabs and add action use the brand blue', (tester) async {
    await _open(tester, _OptionsApi());
    final tab = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Categories'));
    expect(tab.style!.backgroundColor!.resolve({}), AppColors.primary);
    final add = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Add category'));
    expect(add.style!.backgroundColor!.resolve({}), AppColors.primary);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(SegmentedButton<bool>), findsNothing);
  });

  testWidgets('A failed category load still allows category creation and retry', (tester) async {
    final api = _OptionsApi()..failCategories = true;
    await _open(tester, api);
    expect(find.text('Could not load categories'), findsOneWidget);
    final add = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Add category'));
    expect(add.onPressed, isNotNull);
    await tester.tap(find.text('Add category'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Technology');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(api.categories.single['categoryName'], 'Technology');
    expect(find.text('Option created.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    api.failCategories = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load categories'), findsNothing);
    expect(tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Add category')).onPressed, isNotNull);
  });
  testWidgets('Channel form offers an admin-created platform', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        platformsProvider.overrideWith((ref) async => [
          AccountType.youtube, const AccountType('LINKEDIN', 'LinkedIn'),
        ]),
        categoriesProvider.overrideWith((ref) async => [
          AccountCategory(id: 1, categoryName: 'Tech'),
        ]),
      ],
      child: const MaterialApp(home: CreateAccountScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<AccountType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('LinkedIn').last);
    await tester.pumpAndSettle();
    expect(find.text('LinkedIn'), findsOneWidget);
  });

  testWidgets('Admin can create a category and see the saved option', (
    tester,
  ) async {
    final api = _OptionsApi();
    await _open(tester, api);
    await tester.tap(find.text('Add category'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Technology');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Technology'), findsOneWidget);
    expect(api.categories.single['categoryName'], 'Technology');
  });

  testWidgets(
    'Cancel keeps a category; a referenced category survives deletion',
    (tester) async {
      final api = _OptionsApi()
        ..categories.add({'id': 1, 'categoryName': 'Tech', 'displayOrder': 0})
        ..rejectDelete = true;
      await _open(tester, api);
      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(api.deleteCalls, 0);
      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Tech'), findsOneWidget);
      expect(find.textContaining('already used by a channel'), findsOneWidget);
    },
  );

  testWidgets('Admin can add a custom platform', (tester) async {
    final api = _OptionsApi();
    await _open(tester, api);
    await tester.tap(find.text('Platforms'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add platform'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'LinkedIn');
    await tester.enterText(find.byType(TextFormField).at(1), 'linkedin');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(api.platforms.last['code'], 'LINKEDIN');
    expect(find.text('LinkedIn'), findsOneWidget);
  });

  test('New platform names survive channel response parsing', () {
    final account = InfluencerAccount.fromJson({
      'accountType': null,
      'platform': {'code': 'LINKEDIN', 'name': 'LinkedIn'},
    });
    expect(account.accountType!.wire, 'LINKEDIN');
    expect(account.accountType!.label, 'LinkedIn');
    expect(AccountType.fromWire('YOUTUBE'), AccountType.youtube);
  });
}
