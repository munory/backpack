import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/account_provider.dart';
import '../../account/api_client.dart';
import '../../common/input_decoration.dart';
import '../../common/l10n.dart';
import '../../common/theme.dart';
import 'account_fields.dart';

/// Asks to confirm deleting the account — with the password, if it has one:
/// not undoable, so a phone left unlocked on a table shouldn't be enough.
/// Deletes it, and returns true once it's gone.
Future<bool> confirmDeleteAccount(BuildContext context) async =>
    await showDialog<bool>(context: context, builder: (_) => const _DeleteAccountDialog()) ?? false;

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _passwordError;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete(bool needsPassword) async {
    final l = context.l10n;
    if (needsPassword && _password.text.isEmpty) {
      setState(() {
        _passwordError = l.errorEnterPassword;
        _error = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _passwordError = null;
      _error = null;
    });
    try {
      await ref.read(accountProvider.notifier).deleteAccount(password: needsPassword ? _password.text : null);
      if (mounted) Navigator.pop(context, true);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          // A wrong password is the field's problem; anything else, the form's.
          if (e is ApiException && e.code == 'wrong_password') {
            _passwordError = l.errorWrongPassword;
          } else {
            _error = accountErrorText(l, e);
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final account = ref.watch(accountProvider);
    final needsPassword = account is SignedIn && account.user.hasPassword;

    return AlertDialog(
      title: Text(l.deleteAccountTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.deleteAccountBody, style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          if (needsPassword) ...[
            const SizedBox(height: 20),
            FieldLabel(l.passwordToConfirm),
            PasswordField(
              controller: _password,
              error: _passwordError,
              onSubmitted: _busy ? null : () => _delete(true),
            ),
          ],
          ErrorBanner(_error),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context, false),
                style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                child: Text(l.cancel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.overWeight),
                onPressed: _busy ? null : () => _delete(needsPassword),
                child: Text(_busy ? l.pleaseWait : l.deleteAccountConfirm),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
