import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/format.dart';
import '../../providers/data_providers.dart';
import '../../widgets/promotion_brief_details.dart';

class NotificationPromotionScreen extends ConsumerWidget {
  const NotificationPromotionScreen({
    super.key,
    required this.id,
    this.incoming = false,
  });
  final String id;
  final bool incoming;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(notificationPromotionProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Promotion request')),
      body: detail.when(
        loading: () => const LoadingView(),
        error: (_, stack) => ErrorView(
          message:
              'This request could not be loaded. It may no longer be available.',
          onRetry: () => ref.invalidate(notificationPromotionProvider(id)),
        ),
        data: (request) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              request.influencerAccount?.title ?? 'Promotion',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(status: request.status),
            ),
            const SizedBox(height: 16),
            PromotionBriefDetails(request: request),
            if ((request.promotionText ?? '').isNotEmpty)
              Text(request.promotionText!),
            const SizedBox(height: 16),
            if (request.dateList.isNotEmpty)
              Text(
                'Requested posting dates: ${request.dateList.map(Fmt.date).join(', ')}',
              ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () =>
                  context.go(incoming ? '/my-promotions' : '/sent-promotions'),
              child: Text(
                incoming ? 'Open incoming requests' : 'Open sent promotions',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
