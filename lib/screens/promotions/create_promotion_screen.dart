import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/dots_loading.dart';

/// Business owner creates a promotion request against an influencer account.
/// Backend: POST /user/promotion/secure/create-promotion-request-as-business-owner
///   headers: userPublicId (pid), accountPublicId
///   body: { promotionText, promoImageURL, dateList: [ISO dates] }
class CreatePromotionScreen extends ConsumerStatefulWidget {
  const CreatePromotionScreen({
    super.key,
    required this.accountPublicId,
    this.account,
  });

  final String accountPublicId;
  final InfluencerAccount? account;

  @override
  ConsumerState<CreatePromotionScreen> createState() =>
      _CreatePromotionScreenState();
}

class _CreatePromotionScreenState
    extends ConsumerState<CreatePromotionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _text = TextEditingController();
  final _imageUrl = TextEditingController();
  final List<DateTime> _dates = [];
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: now,
    );
    if (picked != null && !_dates.any((d) => _sameDay(d, picked))) {
      setState(() => _dates.add(picked));
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (_dates.isEmpty) {
      setState(() => _error = 'Pick at least one date for the promotion.');
      return;
    }

    final pid = ref.read(authProvider).pid;
    if (pid == null) {
      setState(() => _error = 'Your session expired. Please sign in again.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(apiServiceProvider).createPromotion(
        pid,
        widget.accountPublicId,
        {
          'promotionText': _text.text.trim(),
          if (_imageUrl.text.trim().isNotEmpty)
            'promoImageURL': _imageUrl.text.trim(),
          'dateList': _dates
              .map((d) => DateTime(d.year, d.month, d.day).toIso8601String())
              .toList(),
        },
      );
      // Refresh the user's promotions list so it shows up.
      ref.invalidate(myPromotionsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Promotion request sent.'),
          backgroundColor: AppColors.primary,
        ),
      );
      context.go('/my-promotions');
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = _messageFor(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  String _messageFor(DioException e) {
    final data = e.response?.data;
    if (data is String && data.isNotEmpty) return data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    if (e.type == DioExceptionType.connectionError) {
      return "Can't reach the server. Check your connection.";
    }
    return 'Could not send the request. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    return Scaffold(
      appBar: AppBar(title: const Text('Request promotion')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (account != null) _AccountSummary(account: account),
                const SizedBox(height: 20),
                if (_error != null) _ErrorBanner(message: _error!),
                const Text(
                  'Promotion message',
                  style: TextStyle(
                    color: AppColors.neutral900,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _text,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText:
                        'What should the creator post about your business?',
                  ),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return 'Enter your promotion message';
                    if (s.length < 10) {
                      return 'Add a little more detail (min 10 characters)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Image URL (optional)',
                  style: TextStyle(
                    color: AppColors.neutral900,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _imageUrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    hintText: 'https://...',
                    prefixIcon: Icon(Icons.image_outlined),
                  ),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return null;
                    final ok = Uri.tryParse(s)?.hasAbsolutePath ?? false;
                    return ok ? null : 'Enter a valid URL';
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Dates',
                      style: TextStyle(
                        color: AppColors.neutral900,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _submitting ? null : _pickDate,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add date'),
                    ),
                  ],
                ),
                if (_dates.isEmpty)
                  const Text(
                    'No dates added yet.',
                    style: TextStyle(color: AppColors.neutral500),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _dates
                        .map((d) => Chip(
                              label: Text(Fmt.date(d)),
                              onDeleted: _submitting
                                  ? null
                                  : () => setState(() => _dates.remove(d)),
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.08),
                              deleteIconColor: AppColors.primary,
                              labelStyle:
                                  const TextStyle(color: AppColors.primary),
                              side: BorderSide.none,
                            ))
                        .toList(),
                  ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const DotsLoading()
                      : const Text('Send request'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountSummary extends StatelessWidget {
  const _AccountSummary({required this.account});
  final InfluencerAccount account;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Fmt.platformIcon(account.accountType),
                color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.title ?? 'Creator',
                  style: const TextStyle(
                    color: AppColors.neutral900,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${account.accountType?.label ?? ''} · ${Fmt.compact(account.audienceCount)} audience',
                  style: const TextStyle(
                    color: AppColors.neutral500,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}
