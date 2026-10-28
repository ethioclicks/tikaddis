import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tikaddis/core/api_service.dart';
import 'package:tikaddis/core/channel_address.dart';
import 'package:tikaddis/core/theme.dart';
import 'package:tikaddis/models/models.dart';
import 'package:tikaddis/providers/auth_provider.dart';
import 'package:tikaddis/providers/data_providers.dart';
import 'package:tikaddis/screens/admin/admin_channels_screen.dart';
import 'package:tikaddis/screens/influencer/promotions_screen.dart';

class _ChannelApi extends ApiService {
  bool approved = false;
  int approvals = 0;
  @override
  Future<Response> adminAccountsByStatus(
    String status, {
    int page = 0,
    int size = 30,
  }) async => Response(
    requestOptions: RequestOptions(path: '/test'),
    data: [
      {
        'accountPublicId': 'channel',
        'title': 'TechAddis',
        'approved': approved,
        'accountType': 'TELEGRAM',
      },
    ],
  );
  @override
  Future<Response> adminApproveAccount(String id, String option) async {
    approvals++;
    approved = option == 'APPROVE';
    return Response(
      requestOptions: RequestOptions(path: '/test'),
      statusCode: 200,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Channel handles become usable links and invalid addresses are rejected',
    () {
      expect(
        channelAddress(' @TechAddis ', AccountType.telegram),
        'https://t.me/TechAddis',
      );
      expect(
        channelAddress('BygonePhilosophy', AccountType.youtube),
        'https://www.youtube.com/@BygonePhilosophy',
      );
      expect(
        channelAddress('https://t.me/example', AccountType.telegram),
        'https://t.me/example',
      );
      expect(
        channelAddress('javascript:alert(1)', AccountType.telegram),
        isNull,
      );
      expect(channelAddress('bad user name', AccountType.youtube), isNull);
      expect(
        channelAddress('@example', const AccountType('CUSTOM', 'Custom')),
        isNull,
      );
    },
  );

  test(
    'Channel edit sends required owner header with public channel identifier',
    () async {
      final api = ApiService();
      RequestOptions? captured;
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response(requestOptions: options, statusCode: 201, data: {}),
            );
          },
        ),
      );
      await api.updateInfluencerAccount('signed-in-owner', {
        'accountPublicId': 'channel',
        'title': 'New title',
      });
      expect(captured!.headers['pid'], 'signed-in-owner');
      expect(captured!.data['accountPublicId'], 'channel');
    },
  );

  test(
    'Campaign upload sends a JSON brief and repeated files multipart parts',
    () async {
      final api = ApiService();
      FormData? upload;
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.headers['accountPublicId'], 'channel');
            upload = options.data as FormData;
            handler.resolve(
              Response(requestOptions: options, statusCode: 201, data: {}),
            );
          },
        ),
      );
      await api.createPromotionBrief(
        'channel',
        {
          'campaignTitle': 'Launch',
          'dateList': ['2099-10-31'],
        },
        [
          MultipartFile.fromBytes([1], filename: 'one.png'),
          MultipartFile.fromBytes([2], filename: 'two.pdf'),
        ],
      );
      expect(upload!.files.map((e) => e.key), ['brief', 'files', 'files']);
      expect(
        upload!.files.first.value.contentType.toString(),
        'application/json; charset=utf-8',
      );
      final bytes = await upload!.files.first.value.finalize().fold<List<int>>(
        [],
        (all, chunk) => all..addAll(chunk),
      );
      expect(jsonDecode(utf8.decode(bytes))['campaignTitle'], 'Launch');
    },
  );

  testWidgets('Influencer can respond only at the admin approved stage', (
    tester,
  ) async {
    Future<void> show(PromotionStatus status) async {
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(status),
          overrides: [
            influencerRequestsProvider.overrideWith(
              (ref) async => [
                PromotionRequest(
                  promotionRequestPublicId: 'request',
                  status: status,
                  influencerAccount: InfluencerAccount(title: 'Creator'),
                ),
              ],
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const PromotionsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show(PromotionStatus.requested);
    expect(find.widgetWithText(ElevatedButton, 'Approve'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Reject'), findsNothing);
    await show(PromotionStatus.adminApproved);
    expect(find.widgetWithText(ElevatedButton, 'Approve'), findsOneWidget);
    await show(PromotionStatus.ownerApproved);
    expect(find.widgetWithText(ElevatedButton, 'Approve'), findsNothing);
  });

  testWidgets(
    'Channel approval refreshes immediately and disables repeated approval',
    (tester) async {
      final api = _ChannelApi();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiServiceProvider.overrideWithValue(api)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const AdminChannelsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Approve'));
      await tester.pumpAndSettle();
      expect(api.approvals, 1);
      expect(find.widgetWithText(ElevatedButton, 'Approve'), findsNothing);
      final approvedButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Approved'),
      );
      expect(approvedButton.onPressed, isNull);
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).behavior,
        SnackBarBehavior.floating,
      );
      final reject = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Disapprove'),
      );
      expect(reject.onPressed, isNotNull);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Disapprove'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ElevatedButton, 'Approve'), findsOneWidget);
    },
  );
}
