import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Reauthenticates the account owner before a server-side soft deletion.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key, required this.onDelete});
  final Future<void> Function(String currentPassword) onDelete;

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _confirmed = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_confirmed || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onDelete(_password.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      var message = 'Could not delete your account. Please try again.';
      if (error is DioException) {
        if (error.response?.statusCode == 403) {
          message = 'Your current password is incorrect.';
        } else if (error.response?.statusCode == 401) {
          message = 'Please sign in again before deleting your account.';
        } else if (error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout) {
          message = 'Check your internet connection and try again.';
        }
      }
      setState(() {
        _busy = false;
        _error = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text('Delete your account?'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Your account will be deactivated and your channels hidden. '
                  'You will lose access to the account. Stored records will be retained; '
                  'this does not permanently erase your data.',
                  style: TextStyle(color: AppColors.neutral600, height: 1.5),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  enabled: !_busy,
                  maxLength: 256,
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) => (value ?? '').isEmpty
                      ? 'Enter your current password'
                      : null,
                ),
                CheckboxListTile(
                  value: _confirmed,
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'I understand my records will be retained.',
                    style: TextStyle(fontSize: 13),
                  ),
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _confirmed = value ?? false),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFB91C1C)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB91C1C),
            foregroundColor: Colors.white,
          ),
          onPressed: _busy || !_confirmed ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Delete account'),
        ),
      ],
    ),
  );
}
