import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/account_provider.dart';
import '../../account/api_client.dart';
import '../../common/input_decoration.dart';
import '../../common/l10n.dart';
import '../../common/primary_button.dart';
import '../../common/theme.dart';
import 'account_fields.dart';
import 'code_step.dart';

/// "Не помню пароль": email → a 6-digit code arrives → code + new password →
/// signed in. Two steps on one screen.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.email = ''});

  /// Whatever was typed on the sign-in screen, so it needn't be typed twice.
  final String email;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  late final _email = TextEditingController(text: widget.email);
  final _code = TextEditingController();
  final _password = TextEditingController();

  /// Set once a code has been sent: the screen moves to its second step.
  String? _sentTo;
  bool _busy = false;

  /// Shown under their field: a malformed email or code, a short password —
  /// and a code the server refused, since that's the code field's problem.
  String? _emailError;
  String? _codeError;
  String? _passwordError;

  /// Everything else (no connection, too many tries), in a banner.
  String? _error;

  @override
  void initState() {
    super.initState();
    _email.addListener(() {
      if (_emailError != null) setState(() => _emailError = null);
    });
    _code.addListener(() {
      if (_codeError != null) setState(() => _codeError = null);
    });
    _password.addListener(() {
      if (_passwordError != null) setState(() => _passwordError = null);
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Emails a code; true if that worked (the resend link restarts its countdown).
  Future<bool> _sendCode() async {
    final l = context.l10n;
    final email = _email.text.trim();
    if (!looksLikeEmail(email)) {
      setState(() {
        _emailError = l.errorInvalidEmail;
        _error = null;
      });
      return false;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).requestPasswordReset(email, language: l.localeName);
      if (mounted) setState(() => _sentTo = email);
      return true;
    } on Object catch (e) {
      if (mounted) setState(() => _error = accountErrorText(l, e));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final l = context.l10n;
    final code = sixDigits(_code);
    final passwordError = _password.text.length < minPasswordLength ? l.errorPasswordTooShort : null;
    if (code == null || passwordError != null) {
      setState(() {
        _codeError = code == null ? l.errorCodeDigits : null;
        _passwordError = passwordError;
        _error = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(accountProvider.notifier).resetPassword(_sentTo!, code, _password.text);
      TextInput.finishAutofillContext();
      messenger.showSnackBar(SnackBar(content: Text(l.signedInAs(_sentTo!))));
      // Back past the sign-in screen too — straight to where it started.
      navigator.popUntil((route) => route.isFirst);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          // A refused code is the code field's problem; anything else, the form's.
          if (e is ApiException && e.code == 'invalid_code') {
            _codeError = l.errorInvalidCode;
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
    final sentTo = _sentTo;
    final muted = TextStyle(color: AppColors.textSecondary, fontSize: 14);

    return Scaffold(
      appBar: AppBar(title: Text(l.resetTitle)),
      body: AutofillGroup(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (sentTo == null) ...[
              Text(l.resetIntro, style: muted),
              const SizedBox(height: 24),
              FieldLabel(l.email),
              EmailField(
                controller: _email,
                autofocus: widget.email.isEmpty,
                onSubmitted: () => _sendCode(),
                error: _emailError,
              ),
              ErrorBanner(_error),
              const SizedBox(height: 20),
              PrimaryButton(label: _busy ? l.pleaseWait : l.sendCode, onPressed: _busy ? null : () => _sendCode()),
            ] else ...[
              Text(l.codeSentTo(sentTo), style: muted),
              const SizedBox(height: 24),
              FieldLabel(l.code),
              CodeField(controller: _code, error: _codeError),
              const SizedBox(height: 20),
              FieldLabel(l.newPassword),
              PasswordField(
                controller: _password,
                isNew: true,
                rule: l.passwordRule,
                error: _passwordError,
                onSubmitted: _busy ? null : _confirm,
              ),
              ErrorBanner(_error),
              const SizedBox(height: 20),
              PrimaryButton(label: _busy ? l.pleaseWait : l.saveAndSignIn, onPressed: _busy ? null : _confirm),
              const SizedBox(height: 12),
              ResendCodeLink(onResend: _sendCode, enabled: !_busy),
            ],
          ],
        ),
      ),
    );
  }
}
