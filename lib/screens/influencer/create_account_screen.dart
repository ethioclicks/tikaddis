import '../../widgets/app_toast.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/channel_address.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/channel_detail_view.dart';
import '../../widgets/image_upload.dart';
import '../auth/auth_scaffold.dart' show AuthButton, AuthScaffold;

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
  // Top viewed post (all time) and this week's top viewed post: link + count.
  final _topUrl = TextEditingController();
  final _topCount = TextEditingController();
  final _weekUrl = TextEditingController();
  final _weekCount = TextEditingController();

  AccountType? _accountType;
  AccountCategory? _category;

  /// The channel's profile image (path or link). Shown on Browse and on the
  /// featured card.
  String? _imageUrl;
  bool _uploadingImage = false;
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
      if (a.topViewedPost != null) {
        _topUrl.text = a.topViewedPost!.url;
        _topCount.text = a.topViewedPost!.count.toString();
      }
      if (a.weeklyTopViewedPost != null) {
        _weekUrl.text = a.weeklyTopViewedPost!.url;
        _weekCount.text = a.weeklyTopViewedPost!.count.toString();
      }
      _accountType = a.accountType;
      _category = a.category;
      _imageUrl = (a.imageURL ?? '').isEmpty ? null : a.imageURL;
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
    _topUrl.dispose();
    _topCount.dispose();
    _weekUrl.dispose();
    _weekCount.dispose();
    for (final p in _prices) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() => _uploadingImage = true);
    final url = await pickAndUploadImage(context, ref);
    if (!mounted) return;
    setState(() {
      _uploadingImage = false;
      if (url != null) _imageUrl = url;
    });
  }

  /// A view-post entry as {url, count}, or null when both fields are blank.
  /// Throws a message when only one of the two is filled.
  Map<String, dynamic>? _viewPost(
    TextEditingController url,
    TextEditingController count,
  ) {
    final u = url.text.trim();
    final c = count.text.trim();
    if (u.isEmpty && c.isEmpty) return null;
    return {'url': channelAddress(u, _accountType) ?? u, 'count': int.parse(c)};
  }

  /// Builds the request body from the form. Assumes the form has validated.
  Map<String, dynamic> _buildBody() {
    final priceOptions = _prices
        .where((p) => p.cost.text.trim().isNotEmpty)
        .map(
          (p) => {
            'priceType': p.type.wire,
            'cost': double.tryParse(p.cost.text.trim()) ?? 0,
            if (p.remark.text.trim().isNotEmpty) 'remark': p.remark.text.trim(),
          },
        )
        .toList();

    final top = _viewPost(_topUrl, _topCount);
    final week = _viewPost(_weekUrl, _weekCount);

    return {
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'accountURL': channelAddress(_url.text, _accountType),
      'accountType': AccountType.values.contains(_accountType)
          ? _accountType!.wire
          : null,
      'platformCode': _accountType!.wire,
      if (_isEdit) 'category': {'id': _category!.id},
      'audienceCount': int.tryParse(_audience.text.trim()) ?? 0,
      'minViewPerPostCount': int.tryParse(_minViews.text.trim()) ?? 0,
      'maxViewPerPostCount': int.tryParse(_maxViews.text.trim()) ?? 0,
      'priceOptions': priceOptions,
      // When editing, always send the image ('' clears it) so removing works
      // and an edit never wipes it by omission. On create, only if chosen.
      if (_isEdit || _imageUrl != null) 'imageURL': _imageUrl ?? '',
      // Backend carries the two posts in these collections (each {url, count}).
      if (top != null) 'topViews': [top],
      if (week != null) 'recentViewCounts': [week],
    };
  }

  /// Validates the form and common fields. Returns true when ready to proceed.
  bool _validate() {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return false;
    if (_accountType == null) {
      setState(() => _error = 'Choose a platform.');
      return false;
    }
    if (_category == null || _category!.id == null) {
      setState(() => _error = 'Choose a category.');
      return false;
    }
    return true;
  }

  /// Create flow step 1: validate, then show the preview page. Nothing is
  /// submitted until the user confirms on the preview.
  Future<void> _next() async {
    if (!_validate()) return;
    final preview = _previewAccount(_buildBody());
    final confirmed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChannelPreviewScreen(account: preview),
      ),
    );
    if (confirmed == true) {
      await _submit();
    }
  }

  /// Builds an InfluencerAccount purely for the read-only preview.
  InfluencerAccount _previewAccount(Map<String, dynamic> body) {
    final top = _viewPost(_topUrl, _topCount);
    final week = _viewPost(_weekUrl, _weekCount);
    return InfluencerAccount(
      title: body['title'] as String?,
      description: body['description'] as String?,
      accountURL: body['accountURL'] as String?,
      imageURL: _imageUrl,
      accountType: _accountType,
      audienceCount: body['audienceCount'] as int,
      minViewPerPostCount: body['minViewPerPostCount'] as int,
      maxViewPerPostCount: body['maxViewPerPostCount'] as int,
      category: _category,
      priceOptions: _prices
          .where((p) => p.cost.text.trim().isNotEmpty)
          .map(
            (p) => PriceOptions(
              priceType: p.type,
              cost: double.tryParse(p.cost.text.trim()) ?? 0,
              remark: p.remark.text.trim().isEmpty
                  ? null
                  : p.remark.text.trim(),
            ),
          )
          .toList(),
      topViewedPost: top == null
          ? null
          : ViewPost(url: top['url'] as String, count: top['count'] as int),
      weeklyTopViewedPost: week == null
          ? null
          : ViewPost(url: week['url'] as String, count: week['count'] as int),
      approved: false,
    );
  }

  Future<void> _submit() async {
    if (_isEdit && !_validate()) return;

    final pid = ref.read(authProvider).pid;
    if (pid == null) {
      setState(() => _error = 'Your session expired. Please sign in again.');
      return;
    }

    final body = _buildBody();
    setState(() => _submitting = true);
    try {
      final api = ref.read(apiServiceProvider);
      if (_isEdit) {
        await api.updateInfluencerAccount(pid, {
          'id': widget.editing!.id,
          'accountPublicId': widget.editing!.accountPublicId,
          ...body,
        });
        ref.invalidate(myAccountsProvider);
        ref.invalidate(accountDetailProvider(widget.editing!.accountPublicId!));
      } else {
        await api.createInfluencerAccount(pid, _category!.id!, body);
        ref.invalidate(myAccountsProvider);
      }
      if (!mounted) return;
      AppToast.success(
        context,
        _isEdit ? 'Channel updated.' : 'Account submitted for approval.',
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
    final platforms = ref.watch(platformsProvider);

    final base = Theme.of(context);

    return Theme(
      // Soft grey, borderless fields everywhere in this form, like sign-in.
      data: base.copyWith(inputDecorationTheme: _fieldTheme(base)),
      // The same gradient header and white sheet as Register and the creator
      // profile screens.
      child: AuthScaffold(
        titleInHeader: true,
        title: _isEdit ? 'Edit channel' : 'Add a channel',
        subtitle: '',
        onBack: () => context.canPop() ? context.pop() : context.go('/browse'),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                if (_error != null) _ErrorBanner(message: _error!),

                _label('Channel image'),
                _ChannelImagePicker(
                  imageUrl: _imageUrl,
                  uploading: _uploadingImage,
                  onPick: _submitting || _uploadingImage ? null : _pickImage,
                  onRemove: _submitting || _uploadingImage
                      ? null
                      : () => setState(() => _imageUrl = null),
                ),
                const SizedBox(height: 16),

                _label('Platform'),
                platforms.when(
                  loading: () => const _InlineLoader(),
                  error: (e, _) => _InlineError(
                    message: "Couldn't load platforms.",
                    onRetry: () => ref.invalidate(platformsProvider),
                  ),
                  data: (list) {
                    if (list.isEmpty) {
                      return const Text(
                        'No platforms are available yet. '
                        'Please contact the administrator.',
                      );
                    }
                    final selected = _accountType;
                    final items = {...list, ?selected}.toList();
                    return DropdownButtonFormField<AccountType>(
                      initialValue: selected,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.devices_outlined),
                        hintText: 'Select platform',
                      ),
                      items: items
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(t.label),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _accountType = v),
                      validator: (v) => v == null ? 'Choose a platform' : null,
                    );
                  },
                ),
                const SizedBox(height: 16),

                _label('Category'),
                categories.when(
                  loading: () => const _InlineLoader(),
                  error: (e, _) => _InlineError(
                    onRetry: () => ref.invalidate(categoriesProvider),
                  ),
                  data: (list) {
                    if (list.isEmpty && _category == null) {
                      return const Text(
                        'No categories are available yet. '
                        'Please contact the administrator.',
                      );
                    }
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
                      initialValue: items.contains(selected) ? selected : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.category_outlined),
                        hintText: 'Select category',
                      ),
                      items: items
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(c.categoryName ?? 'Category'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _category = v),
                      validator: (v) => v == null ? 'Choose a category' : null,
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
                  buildCounter:
                      (
                        context, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => Padding(
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

                _label('Channel link or username'),
                TextFormField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  maxLength: 255,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.link),
                    hintText: 'https://... or @yourchannel',
                    helperText:
                        'A link, @handle or username for your platform.',
                    helperMaxLines: 2,
                    counterText: '',
                  ),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return 'Enter a channel link or username';
                    if (channelAddress(s, _accountType) == null) {
                      return 'Enter a valid link or platform username';
                    }
                    if (s.length > 255) return 'URL is too long';
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                const _SectionHeader(
                  title: 'Audience and reach',
                  subtitle: 'Help brands judge how far you reach.',
                ),
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

                _label('Top viewed post (optional)'),
                _ViewPostFields(
                  urlController: _topUrl,
                  countController: _topCount,
                  accountType: _accountType,
                ),
                const SizedBox(height: 16),

                _label("This week's top viewed post (optional)"),
                _ViewPostFields(
                  urlController: _weekUrl,
                  countController: _weekCount,
                  accountType: _accountType,
                ),
                const SizedBox(height: 24),

                const SizedBox(height: 4),
                _SectionHeader(
                  title: 'Pricing',
                  subtitle: 'What you charge for a promotion.',
                  trailing: TextButton.icon(
                    onPressed: _submitting
                        ? null
                        : () => setState(
                            () => _prices.add(_PriceRowData(PriceType.perView)),
                          ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text(
                      'Add price',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                ..._prices.asMap().entries.map(
                  (e) => _PriceRow(
                    key: ValueKey(e.value),
                    data: e.value,
                    canRemove: _prices.length > 1,
                    onTypeChanged: (t) => setState(() => e.value.type = t),
                    onRemove: () {
                      e.value.dispose();
                      setState(() => _prices.removeAt(e.key));
                    },
                  ),
                ),
                const SizedBox(height: 28),

                AuthButton(
                  label: _isEdit ? 'Save changes' : 'Next',
                  loading: _submitting,
                  onPressed: _isEdit ? _submit : _next,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Soft grey, borderless fields that turn blue when focused (red on error).
  static InputDecorationThemeData _fieldTheme(ThemeData base) {
    OutlineInputBorder border(Color? color, [double width = 1.4]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: color == null
              ? BorderSide.none
              : BorderSide(color: color, width: width),
        );
    return base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: AppColors.neutral100,
      hintStyle: const TextStyle(color: AppColors.neutral500, fontSize: 15),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(null),
      enabledBorder: border(null),
      disabledBorder: border(null),
      focusedBorder: border(AppColors.primary, 1.6),
      errorBorder: border(const Color(0xFFDC2626), 1.2),
      focusedErrorBorder: border(const Color(0xFFDC2626), 1.6),
    );
  }

  String? _viewValidator(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Required';
    if (int.tryParse(s) == null) return 'Number';
    return null;
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.neutral700,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// Pick / change / remove the channel's profile image.
class _ChannelImagePicker extends StatelessWidget {
  const _ChannelImagePicker({
    required this.imageUrl,
    required this.uploading,
    required this.onPick,
    required this.onRemove,
  });

  final String? imageUrl;
  final bool uploading;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final has = (imageUrl ?? '').isNotEmpty;
    final busy = onPick == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: onPick,
                  style: FilledButton.styleFrom(
                    backgroundColor: has
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.neutral100,
                    foregroundColor:
                        has ? AppColors.primary : AppColors.neutral900,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  icon: uploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          has
                              ? Icons.check_circle_outline
                              : Icons.add_photo_alternate_outlined,
                          size: 20,
                        ),
                  label: Text(
                    uploading
                        ? 'Uploading...'
                        : has
                            ? 'Image added - tap to change'
                            : 'Upload channel image',
                  ),
                ),
              ),
            ),
            if (has && !uploading) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Remove image',
                onPressed: busy ? null : onRemove,
                icon: const Icon(Icons.close, color: AppColors.neutral500),
              ),
            ],
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(left: 2, top: 6),
          child: Text(
            'Shown on Browse. JPG or PNG, up to 5 MB.',
            style: TextStyle(color: AppColors.neutral500, fontSize: 12.5),
          ),
        ),
      ],
    );
  }
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
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
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
              icon: const Icon(
                Icons.remove_circle_outline,
                color: Color(0xFFB91C1C),
              ),
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
        Text(
          'Loading categories...',
          style: TextStyle(color: AppColors.neutral500),
        ),
      ],
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({
    required this.onRetry,
    this.message = "Couldn't load categories.",
  });
  final VoidCallback onRetry;
  final String message;
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
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Color(0xFFB91C1C)),
          ),
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

/// A link + view-count pair for a "top viewed post". Both fields are optional,
/// but if one is filled the other becomes required, and the count must be a
/// non-negative whole number.
class _ViewPostFields extends StatelessWidget {
  const _ViewPostFields({
    required this.urlController,
    required this.countController,
    required this.accountType,
  });

  final TextEditingController urlController;
  final TextEditingController countController;
  final AccountType? accountType;

  bool get _hasUrl => urlController.text.trim().isNotEmpty;
  bool get _hasCount => countController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: urlController,
          keyboardType: TextInputType.url,
          maxLength: 2048,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.link),
            hintText: 'https://... (post or video link)',
            counterText: '',
          ),
          validator: (v) {
            final s = (v ?? '').trim();
            if (s.isEmpty) {
              return _hasCount ? 'Add the post link too' : null;
            }
            if (channelAddress(s, accountType) == null) {
              return 'Enter a valid link';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: countController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.visibility_outlined),
            hintText: 'View count',
          ),
          validator: (v) {
            final s = (v ?? '').trim();
            if (s.isEmpty) {
              return _hasUrl ? 'Add the view count too' : null;
            }
            final n = int.tryParse(s);
            if (n == null || n < 0) return 'Enter a whole number of 0 or more';
            return null;
          },
        ),
      ],
    );
  }
}

/// Read-only preview of a channel before it is submitted: the same page the
/// owner will see, with a PENDING status. "Go back and edit" returns false;
/// "Submit" returns true so the create screen performs the actual submit.
class ChannelPreviewScreen extends StatelessWidget {
  const ChannelPreviewScreen({super.key, required this.account});

  final InfluencerAccount account;

  @override
  Widget build(BuildContext context) {
    ButtonStyle style(Color bg, Color fg) => FilledButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: 0,
      minimumSize: const Size.fromHeight(54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: ChannelDetailView(
              account: account,
              leading: HeaderIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.neutral200)),
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              12 + MediaQuery.of(context).padding.bottom,
            ),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: style(AppColors.neutral100, AppColors.neutral900),
                    child: const Text('Go back and edit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: style(AppColors.primary, Colors.white),
                    child: const Text('Submit'),
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

/// Section title with a short helper line and an optional action on the right.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.neutral500,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
