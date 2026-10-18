import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/dots_loading.dart';

/// Create a new influencer account.
/// Backend: POST /influencer/create-influencer-account/{categoryId}
///   header: pid
///   body: InfluencerAccount { title, description, accountURL, imageURL,
///          accountType, audienceCount, minViewPerPostCount,
///          maxViewPerPostCount, priceOptions:[{priceType,cost,remark}] }
class CreateAccountScreen extends ConsumerStatefulWidget {
  const CreateAccountScreen({super.key, this.editing});

  /// When provided, the screen is in edit mode and updates this account.
  final InfluencerAccount? editing;

  @override
  ConsumerState<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _PriceRowData {
  PriceType type;
  final TextEditingController cost;
  final TextEditingController remark;
  _PriceRowData(this.type)
      : cost = TextEditingController(),
        remark = TextEditingController();
  void dispose() {
    cost.dispose();
    remark.dispose();
  }
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _url = TextEditingController();
  final _audience = TextEditingController();
  final _minViews = TextEditingController();
  final _maxViews = TextEditingController();

  AccountType? _accountType;
  AccountCategory? _category;
  final List<_PriceRowData> _prices = [];

  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final a = widget.editing;
    if (a != null) {
      _title.text = a.title ?? '';
      _description.text = a.description ?? '';
      _url.text = a.accountURL ?? '';
      _audience.text = a.audienceCount.toString();
      _minViews.text = a.minViewPerPostCount.toString();
      _maxViews.text = a.maxViewPerPostCount.toString();
      _accountType = a.accountType;
      _category = a.category;
      for (final p in a.priceOptions) {
        final row = _PriceRowData(p.priceType ?? PriceType.perDay);
        row.cost.text = p.cost == p.cost.roundToDouble()
            ? p.cost.toStringAsFixed(0)
            : p.cost.toString();
        row.remark.text = p.remark ?? '';
        _prices.add(row);
      }
    }
    if (_prices.isEmpty) {
      _prices.add(_PriceRowData(PriceType.perDay));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _url.dispose();
    _audience.dispose();
    _minViews.dispose();
    _maxViews.dispose();
    for (final p in _prices) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (_accountType == null) {
      setState(() => _error = 'Choose a platform.');
      return;
    }
    if (_category == null || _category!.id == null) {
      setState(() => _error = 'Choose a category.');
      return;
    }

    final pid = ref.read(authProvider).pid;
    if (pid == null) {
      setState(() => _error = 'Your session expired. Please sign in again.');
      return;
    }

    final priceOptions = _prices
        .where((p) => p.cost.text.trim().isNotEmpty)
        .map((p) => {
              'priceType': p.type.wire,
              'cost': double.tryParse(p.cost.text.trim()) ?? 0,
              if (p.remark.text.trim().isNotEmpty)
                'remark': p.remark.text.trim(),
            })
        .toList();

    final body = {
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'accountURL': _url.text.trim(),
      'accountType': _accountType!.wire,
      'audienceCount': int.tryParse(_audience.text.trim()) ?? 0,
      'minViewPerPostCount': int.tryParse(_minViews.text.trim()) ?? 0,
      'maxViewPerPostCount': int.tryParse(_maxViews.text.trim()) ?? 0,
      'priceOptions': priceOptions,
    };

    setState(() => _submitting = true);
    try {
      final api = ref.read(apiServiceProvider);
      if (_isEdit) {
        await api.updateInfluencerAccount({
          'id': widget.editing!.id,
          'accountPublicId': widget.editing!.accountPublicId,
          ...body,
        });
        ref.invalidate(myAccountsProvider);
        ref.invalidate(
            accountDetailProvider(widget.editing!.accountPublicId!));
      } else {
        await api.createInfluencerAccount(pid, _category!.id!, body);
        ref.invalidate(myAccountsProvider);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit
              ? 'Channel updated.'
              : 'Account submitted for approval.'),
          backgroundColor: AppColors.primary,
        ),
      );
      if (_isEdit) {
        context.pop(); // back to the channel detail
      } else {
        context.go('/browse'); // back to the Channels list
      }
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
    return 'Could not create the account. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
          title: Text(_isEdit ? 'Edit channel' : 'Add a channel')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) _ErrorBanner(message: _error!),

                _label('Platform'),
                DropdownButtonFormField<AccountType>(
                  initialValue: _accountType,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.devices_outlined),
                    hintText: 'Select platform',
                  ),
                  items: AccountType.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.label),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _accountType = v),
                  validator: (v) => v == null ? 'Choose a platform' : null,
                ),
                const SizedBox(height: 16),

                _label('Category'),
                categories.when(
                  loading: () => const _InlineLoader(),
                  error: (e, _) => _InlineError(
                    onRetry: () => ref.invalidate(categoriesProvider),
                  ),
                  data: (list) {
                    // Resolve the selected value to the exact instance in the
                    // fetched list (by id equality) to satisfy the dropdown.
                    final selected = _category == null
                        ? null
                        : list.firstWhere(
                            (c) => c.id == _category!.id,
                            orElse: () => _category!,
                          );
                    final items = {...list, ?selected}.toList();
                    return DropdownButtonFormField<AccountCategory>(
                      initialValue:
                          items.contains(selected) ? selected : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.category_outlined),
                        hintText: 'Select category',
                      ),
                      items: items
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.categoryName ?? 'Category'),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _category = v),
                      validator: (v) =>
                          v == null ? 'Choose a category' : null,
                    );
                  },
                ),
                const SizedBox(height: 16),

                _label('Title'),
                TextFormField(
                  controller: _title,
                  maxLength: 255,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Addis Tech Daily',
                    counterText: '',
                  ),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return 'Enter a title';
                    if (s.length > 255) return 'Keep it under 255 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                _label('Description'),
                TextFormField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 255,
                  decoration: const InputDecoration(
                    hintText: 'What is your channel about?',
                    counterText: '',
                  ),
                  buildCounter: (context,
                          {required currentLength,
                          required isFocused,
                          maxLength}) =>
                      Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$currentLength/$maxLength',
                      style: TextStyle(
                        fontSize: 11,
                        color: currentLength >= (maxLength ?? 255)
                            ? const Color(0xFFB91C1C)
                            : AppColors.neutral500,
                      ),
                    ),
                  ),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return 'Enter a description';
                    if (s.length > 255) {
                      return 'Keep it under 255 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                _label('Channel URL'),
                TextFormField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  maxLength: 255,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.link),
                    hintText: 'https://t.me/yourchannel',
                    counterText: '',
                  ),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return 'Enter the channel URL';
                    final ok = Uri.tryParse(s)?.hasAbsolutePath ?? false;
                    if (!ok) return 'Enter a valid URL';
                    if (s.length > 255) return 'URL is too long';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                _label('Audience count'),
                TextFormField(
                  controller: _audience,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.group_outlined),
                    hintText: 'e.g. 50000',
                  ),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n <= 0) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                _label('Views per post (range)'),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _minViews,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: 'Min'),
                        validator: _viewValidator,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _maxViews,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: 'Max'),
                        validator: (v) {
                          final base = _viewValidator(v);
                          if (base != null) return base;
                          final min = int.tryParse(_minViews.text.trim()) ?? 0;
                          final max = int.tryParse((v ?? '').trim()) ?? 0;
                          if (max < min) return 'Max < min';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _label('Pricing'),
                    TextButton.icon(
                      onPressed: _submitting
                          ? null
                          : () => setState(() =>
                              _prices.add(_PriceRowData(PriceType.perView))),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add price'),
                    ),
                  ],
                ),
                ..._prices.asMap().entries.map((e) => _PriceRow(
                      key: ValueKey(e.value),
                      data: e.value,
                      canRemove: _prices.length > 1,
                      onTypeChanged: (t) => setState(() => e.value.type = t),
                      onRemove: () {
                        e.value.dispose();
                        setState(() => _prices.removeAt(e.key));
                      },
                    )),
                const SizedBox(height: 28),

                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const DotsLoading()
                      : Text(_isEdit ? 'Save changes' : 'Submit for approval'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _viewValidator(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Required';
    if (int.tryParse(s) == null) return 'Number';
    return null;
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.neutral900,
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    super.key,
    required this.data,
    required this.canRemove,
    required this.onTypeChanged,
    required this.onRemove,
  });
  final _PriceRowData data;
  final bool canRemove;
  final ValueChanged<PriceType> onTypeChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<PriceType>(
              initialValue: data.type,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              items: PriceType.values
                  .map((t) =>
                      DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (v) => v == null ? null : onTypeChanged(v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: data.cost,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                prefixText: 'ETB ',
                hintText: '0',
              ),
            ),
          ),
          if (canRemove)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline,
                  color: Color(0xFFB91C1C)),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

class _InlineLoader extends StatelessWidget {
  const _InlineLoader();
  @override
  Widget build(BuildContext context) => Container(
        height: 56,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.neutral50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.neutral200),
        ),
        child: const Row(
          children: [
            SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Loading categories...',
                style: TextStyle(color: AppColors.neutral500)),
          ],
        ),
      );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text("Couldn't load categories.",
                  style: TextStyle(color: Color(0xFFB91C1C))),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
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
