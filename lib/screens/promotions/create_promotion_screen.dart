import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/dots_loading.dart';

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

class _CreatePromotionScreenState extends ConsumerState<CreatePromotionScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = {
    for (final key in [
      'campaignTitle',
      'brandName',
      'objective',
      'targetAudience',
      'deliverables',
      'callToAction',
      'promotionText',
      'proposedBudget',
    ])
      key: TextEditingController(),
  };
  final List<DateTime> _dates = [];
  final List<PlatformFile> _files = [];
  bool _busy = false;
  bool _picking = false;

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _date() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      initialDate: _dates.isEmpty ? now : _dates.last,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (!mounted || picked == null) return;
    if (_dates.length >= 30) {
      AppToast.error(context, 'Choose at most 30 posting dates.');
      return;
    }
    if (!_dates.contains(picked)) {
      setState(() {
        _dates.add(picked);
        _dates.sort();
      });
    }
  }

  Future<void> _attach() async {
    setState(() => _picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        allowMultiple: true,
        withData: kIsWeb,
      );
      if (!mounted || result == null) return;
      if (_files.length + result.files.length > 5) {
        AppToast.error(context, 'Attach at most five files.');
        return;
      }
      if (result.files.any((f) => f.size == 0 || f.size > 5 * 1024 * 1024)) {
        AppToast.error(context, 'Each file must be between 1 byte and 5 MB.');
        return;
      }
      setState(() => _files.addAll(result.files));
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Could not select files. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_dates.isEmpty) {
      AppToast.error(context, 'Choose at least one requested posting date.');
      return;
    }
    setState(() => _busy = true);
    try {
      final uploads = <MultipartFile>[];
      for (final f in _files) {
        final bytes =
            f.bytes ??
            (f.path == null ? null : await File(f.path!).readAsBytes());
        if (bytes == null || bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
          throw StateError('Attachment is unavailable or too large.');
        }
        uploads.add(MultipartFile.fromBytes(bytes, filename: f.name));
      }
      final brief = <String, dynamic>{
        for (final entry in _fields.entries)
          if (entry.key != 'proposedBudget' &&
              entry.value.text.trim().isNotEmpty)
            entry.key: entry.value.text.trim(),
        if (_fields['proposedBudget']!.text.trim().isNotEmpty)
          'proposedBudget': double.parse(
            _fields['proposedBudget']!.text.trim(),
          ),
        'dateList': _dates.map((d) => '${Fmt.date(d)}T12:00:00+03:00').toList(),
      };
      await ref
          .read(apiServiceProvider)
          .createPromotionBrief(widget.accountPublicId, brief, uploads);
      ref.invalidate(myPromotionsProvider);
      ref.invalidate(adminPromotionsProvider);
      if (!mounted) return;
      AppToast.success(context, 'Campaign request sent for admin review.');
      context.go('/my-promotions');
    } catch (error) {
      if (!mounted) return;
      var message =
          'Could not send the request. Your brief is still here; please retry.';
      if (error is DioException) {
        final data = error.response?.data;
        if (data is Map && data['message'] is String) message = data['message'];
        if (error.response?.statusCode == 413) {
          message = 'Attachments exceed the upload limit. Use smaller files.';
        }
      } else if (error is StateError) {
        message = error.message;
      }
      AppToast.error(context, message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    String key,
    String label,
    String hint, {
    bool required = false,
    int max = 500,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextFormField(
      controller: _fields[key],
      enabled: !_busy,
      maxLength: max,
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 3,
      decoration: InputDecoration(
        labelText: '$label${required ? ' *' : ' (optional)'}',
        hintText: hint,
        alignLabelWithHint: lines > 1,
      ),
      validator: (value) {
        final text = (value ?? '').trim();
        if (required && text.isEmpty) return 'Enter ${label.toLowerCase()}';
        if (key == 'promotionText' && text.length < 10) {
          return 'Describe your campaign in at least 10 characters';
        }
        return null;
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final platformColor = Fmt.platformColor(account?.accountType);
    return Scaffold(
      appBar: AppBar(title: const Text('Request promotion')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (account != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: platformColor.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Fmt.platformIcon(account.accountType),
                        color: platformColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.title ?? 'Channel',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${account.accountType?.label ?? ''} · ${Fmt.compact(account.audienceCount)} audience',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              const Text(
                'Campaign brief',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tell the creator what you need. An administrator reviews your request before the creator can accept it.',
                style: TextStyle(color: AppColors.neutral600),
              ),
              const SizedBox(height: 24),
              _field(
                'campaignTitle',
                'Campaign title',
                'e.g. New product launch',
                required: true,
                max: 120,
              ),
              _field(
                'brandName',
                'Brand or business',
                'Your business name',
                required: true,
                max: 120,
              ),
              _field(
                'objective',
                'Campaign objective',
                'e.g. Introduce our product and drive enquiries',
                required: true,
                lines: 2,
              ),
              _field(
                'targetAudience',
                'Target audience',
                'Location, language, age range and interests',
                lines: 2,
              ),
              _field(
                'deliverables',
                'Requested deliverables',
                'e.g. One 60-second video and two story posts',
                required: true,
                max: 2000,
                lines: 2,
              ),
              _field(
                'promotionText',
                'Message and creative brief',
                'Product details, key messages, tone, required mentions and things to avoid',
                required: true,
                max: 6000,
                lines: 4,
              ),
              _field(
                'callToAction',
                'Call to action',
                'e.g. Visit our website, call us or use a discount code',
                lines: 2,
              ),
              TextFormField(
                controller: _fields['proposedBudget'],
                enabled: !_busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Proposed budget (optional)',
                  prefixText: 'ETB ',
                  helperText:
                      'A proposal for discussion. Sending this request does not make a payment.',
                  helperMaxLines: 2,
                ),
                validator: (v) {
                  if ((v ?? '').trim().isEmpty) return null;
                  final amount = double.tryParse(v!.trim());
                  return amount == null ||
                          !amount.isFinite ||
                          amount <= 0 ||
                          amount > 100000000 ||
                          !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(v.trim())
                      ? 'Enter a positive budget with up to two decimal places'
                      : null;
                },
              ),
              const SizedBox(height: 28),
              const Text(
                'Creative attachments',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Add artwork, product photos or a PDF brief. Up to 5 JPG, PNG or PDF files, 5 MB each.',
                style: TextStyle(color: AppColors.neutral600),
              ),
              for (final file in _files)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.attach_file),
                  title: Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('${(file.size / 1024).ceil()} KB'),
                  trailing: IconButton(
                    tooltip: 'Remove attachment',
                    icon: const Icon(Icons.close),
                    onPressed: _busy
                        ? null
                        : () => setState(() => _files.remove(file)),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _busy || _picking || _files.length >= 5
                    ? null
                    : _attach,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(_picking ? 'Selecting files…' : 'Attach files'),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Requested posting dates',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _busy ? null : _date,
                    icon: const Icon(Icons.add),
                    label: const Text('Add date'),
                  ),
                ],
              ),
              const Text(
                'Choose the days you want content published. Add multiple dates for separate posting days. These are requested dates, subject to agreement; posts are not published automatically.',
                style: TextStyle(color: AppColors.neutral600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: _dates
                    .map(
                      (date) => Chip(
                        label: Text(Fmt.date(date)),
                        onDeleted: _busy
                            ? null
                            : () => setState(() => _dates.remove(date)),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _busy || _picking ? null : _submit,
                child: _busy
                    ? const DotsLoading()
                    : const Text('Send for admin review'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
