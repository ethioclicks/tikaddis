import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/hex_pattern.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';

/// Admin-owned options shared with the channel creation form.
class AdminChannelOptionsScreen extends ConsumerStatefulWidget {
  const AdminChannelOptionsScreen({super.key});

  @override
  ConsumerState<AdminChannelOptionsScreen> createState() =>
      _AdminChannelOptionsScreenState();
}

class _AdminChannelOptionsScreenState
    extends ConsumerState<AdminChannelOptionsScreen> {
  bool _platforms = false;
  bool _busy = false;

  void _refresh() {
    ref.invalidate(adminCategoriesProvider);
    ref.invalidate(adminPlatformsProvider);
    ref.invalidate(categoriesProvider);
    ref.invalidate(platformsProvider);
    ref.invalidate(adminAccountsProvider);
    ref.invalidate(approvedAccountsProvider);
    ref.invalidate(myAccountsProvider);
  }

  Future<void> _edit({
    AccountCategory? category,
    Map<String, dynamic>? platform,
  }) async {
    final isPlatform = _platforms;
    final existing = category != null || platform != null;
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _OptionEditor(
        isPlatform: isPlatform,
        category: category,
        platform: platform,
      ),
    );
    if (data == null || !mounted) return;
    await _save(() async {
      final api = ref.read(apiServiceProvider);
      if (isPlatform) {
        await api.adminSavePlatform(data, code: platform?['code'] as String?);
      } else if (category?.id != null) {
        await api.adminUpdateCategory(category!.id!, data);
      } else {
        await api.adminCreateCategory(data);
      }
    }, existing ? 'Changes saved.' : 'Option created.');
  }

  Future<void> _delete({
    AccountCategory? category,
    Map<String, dynamic>? platform,
  }) async {
    final name = category?.categoryName ?? platform?['name'] ?? 'this option';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text('Delete $name?'),
        content: const Text(
          'This removes the option from channel selection. '
          'Options used by existing channels cannot be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _save(() async {
      final api = ref.read(apiServiceProvider);
      if (category != null) {
        await api.adminDeleteCategory(category.id!);
      } else {
        await api.adminDeletePlatform(platform!['code'] as String);
      }
    }, 'Option deleted.');
  }

  Future<void> _save(Future<void> Function() action, String message) async {
    setState(() => _busy = true);
    try {
      await action();
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (mounted) {
        var message = 'Could not save this change. Please try again.';
        if (error is DioException) {
          final data = error.response?.data;
          if (data is Map && data['message'] is String) {
            message = data['message'] as String;
          } else if (data is String && data.isNotEmpty && !data.contains('<')) {
            message = data;
          }
          if (error.response?.statusCode == 409) {
            message =
                'This option is already used by a channel or its name '
                'already exists. Update it instead.';
          }
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(adminCategoriesProvider);
    final platforms = ref.watch(adminPlatformsProvider);
    final canAdd = !_busy;
    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.neutral900,
        title: const Text(
          'Channel options',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _busy ? null : _refresh,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: AppColors.primary),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.neutral200)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: PrimaryButton(
              onPressed: canAdd ? () => _edit() : null,
              loading: _busy,
              icon: Icons.add,
              label: _platforms ? 'Add platform' : 'Add category',
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: HexBackground(
                    animate: false,
                    borderRadius: BorderRadius.circular(22),
                    opacity: 0.10,
                    child: const Padding(
                      padding: EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Set up your channels',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Manage the options users select when adding a channel.',
                                  style: TextStyle(
                                    color: Color(0xDDFFFFFF),
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _tab(false, 'Categories', Icons.category_outlined),
                    const SizedBox(width: 12),
                    _tab(true, 'Platforms', Icons.devices_outlined),
                  ],
                ),
              ],
            ),
          ),
          if (_busy) const LinearProgressIndicator(color: AppColors.primary),
          Expanded(
            child: _platforms
                ? platforms.when(
                    loading: () => const LoadingView(),
                    error: (error, _) => _error(error),
                    data: (list) => _list(
                      list
                          .map(
                            (p) => _row(
                              name: p['name'] as String,
                              subtitle:
                                  '${p['code']} · Order ${p['displayOrder'] ?? 0}',
                              onEdit: () => _edit(platform: p),
                              onDelete: () => _delete(platform: p),
                            ),
                          )
                          .toList(),
                    ),
                  )
                : categories.when(
                    loading: () => const LoadingView(),
                    error: (error, _) => _error(error),
                    data: (list) => _list(
                      list
                          .map(
                            (c) => _row(
                              name: c.categoryName ?? 'Category',
                              subtitle: 'Order ${c.displayOrder ?? 0}',
                              onEdit: () => _edit(category: c),
                              onDelete: () => _delete(category: c),
                            ),
                          )
                          .toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tab(bool platforms, String label, IconData icon) {
    final selected = _platforms == platforms;
    return Expanded(
      child: Semantics(
        selected: selected,
        child: OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => setState(() => _platforms = platforms),
          style: OutlinedButton.styleFrom(
            backgroundColor: selected ? AppColors.primary : Colors.white,
            foregroundColor: selected ? Colors.white : AppColors.neutral600,
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.neutral200,
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          icon: Icon(icon, size: 20),
          label: Text(label),
        ),
      ),
    );
  }

  Widget _error(Object error) {
    final type = _platforms ? 'Platforms' : 'Categories';
    var message = '$type are unavailable right now. Please try again later.';
    if (error is DioException &&
        (error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout)) {
      message = 'Check your internet connection and try again.';
    }
    return Center(
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.neutral200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  size: 32,
                  color: AppColors.accentHover,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Could not load ${type.toLowerCase()}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.neutral900,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.neutral500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SecondaryButton(
                label: 'Retry',
                icon: Icons.refresh,
                onPressed: _refresh,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(List<Widget> rows) => rows.isEmpty
      ? EmptyView(
          icon: Icons.category_outlined,
          message: _platforms
              ? 'No platforms yet. Add one to get started.'
              : 'No categories yet. Add one to get started.',
        )
      : RefreshIndicator(
          onRefresh: () async {
            _refresh();
            if (_platforms) {
              await ref.read(adminPlatformsProvider.future);
            } else {
              await ref.read(adminCategoriesProvider.future);
            }
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            physics: const AlwaysScrollableScrollPhysics(),
            children: rows,
          ),
        );

  Widget _row({
    required String name,
    required String subtitle,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) => Card(
    elevation: 0,
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: AppColors.neutral200),
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (_platforms ? AppColors.accent : AppColors.primary).withValues(
            alpha: 0.1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          _platforms ? Icons.public : Icons.category_outlined,
          color: _platforms ? AppColors.accentHover : AppColors.primary,
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(
          fontSize: 15,
          color: AppColors.neutral900,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.neutral500),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Edit',
            onPressed: _busy ? null : onEdit,
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: _busy ? null : onDelete,
            icon: const Icon(Icons.delete_outline, color: Color(0xFFB91C1C)),
          ),
        ],
      ),
    ),
  );
}

class _OptionEditor extends StatefulWidget {
  const _OptionEditor({required this.isPlatform, this.category, this.platform});
  final bool isPlatform;
  final AccountCategory? category;
  final Map<String, dynamic>? platform;

  @override
  State<_OptionEditor> createState() => _OptionEditorState();
}

class _OptionEditorState extends State<_OptionEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text:
        widget.category?.categoryName ??
        widget.platform?['name'] as String? ??
        '',
  );
  late final _code = TextEditingController(
    text: widget.platform?['code'] as String? ?? '',
  );
  late final _order = TextEditingController(
    text:
        '${widget.category?.displayOrder ?? widget.platform?['displayOrder'] ?? 0}',
  );
  late final _image = TextEditingController(
    text: widget.category?.categoryImageUrl ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _order.dispose();
    _image.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.category != null || widget.platform != null;
    final type = widget.isPlatform ? 'platform' : 'category';
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text('${existing ? 'Edit' : 'Add'} $type'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Enter a name' : null,
                ),
                if (widget.isPlatform)
                  TextFormField(
                    controller: _code,
                    enabled: !existing,
                    maxLength: 50,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Platform code',
                      helperText:
                          'Letters, numbers and underscores, e.g. LINKEDIN',
                    ),
                    validator: (v) =>
                        RegExp(
                          r'^[A-Z][A-Z0-9_]{0,49}$',
                        ).hasMatch((v ?? '').trim().toUpperCase())
                        ? null
                        : 'Start with a letter; use letters, numbers or _',
                  ),
                TextFormField(
                  controller: _order,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Display order',
                    helperText: 'Lower numbers appear first',
                  ),
                  validator: (v) {
                    final order = int.tryParse(v ?? '');
                    return order == null || order < 0 || order > 2147483647
                        ? 'Enter a non-negative whole number'
                        : null;
                  },
                ),
                if (!widget.isPlatform)
                  TextFormField(
                    controller: _image,
                    decoration: const InputDecoration(
                      labelText: 'Image URL (optional)',
                    ),
                    validator: (v) {
                      if ((v ?? '').trim().isEmpty) return null;
                      final uri = Uri.tryParse(v!.trim());
                      return uri != null &&
                              uri.hasAuthority &&
                              (uri.scheme == 'https' || uri.scheme == 'http')
                          ? null
                          : 'Enter a valid image URL';
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop(context, <String, dynamic>{
              if (widget.isPlatform) ...{
                'name': _name.text.trim(),
                'code': _code.text.trim().toUpperCase(),
              } else ...{
                'categoryName': _name.text.trim(),
                'categoryImageUrl': _image.text.trim().isEmpty
                    ? null
                    : _image.text.trim(),
              },
              'displayOrder': int.parse(_order.text),
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
