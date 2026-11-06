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
import 'reset_password_screen.dart';

/// Sign in, or create an account — one screen with a switch at the bottom,
/// so an email already typed isn't lost when someone realises they're on the
/// wrong one. Creating an account has a second step: the code emailed to
/// prove the address (the account exists only after it).
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.startWithRegister = false});

  final bool startWithRegister;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  late bool _registering = widget.startWithRegister;
  bool _busy = false;

  /// Set once a sign-up code has been emailed: the screen shows the code step.
  String? _codeSentTo;

  /// Typos and refused codes, shown under their field.
  String? _emailError;
  String? _passwordError;
  String? _codeError;

  /// The server's answer or no connection, shown in a banner.
  String? _error;

  @override
  void initState() {
    super.initState();
    // Typing again means fixing it — the old error goes.
    _email.addListener(() {
      if (_emailError != null) setState(() => _emailError = null);
    });
    _password.addListener(() {
      if (_passwordError != null) setState(() => _passwordError = null);
    });
    _code.addListener(() {
      if (_codeError != null) setState(() => _codeError = null);
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  /// Runs [action] with the button showing "one moment" and any failure
  /// shown — under a field if [onField] takes it, else in the banner.
  /// Returns whether it worked.
  Future<bool> _run(Future<void> Function() action, {bool Function(Object error)? onField}) async {
    final l = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      return true;
    } on Object catch (e) {
      if (mounted && !(onField?.call(e) ?? false)) setState(() => _error = accountErrorText(l, e));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _signedIn(String email) {
    // "Signed in fine" — the cue for a password manager to offer saving
    // this email and password.
    TextInput.finishAutofillContext();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.signedInAs(email))));
    Navigator.of(context).pop();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final email = _email.text.trim();
    final password = _password.text;
    // Typos caught here, before a round trip to the server.
    final emailError = looksLikeEmail(email) ? null : l.errorInvalidEmail;
    final passwordError = password.isEmpty
        ? l.errorEnterPassword
        : _registering && password.length < minPasswordLength
        ? l.errorPasswordTooShort
        : null;
    if (emailError != null || passwordError != null) {
      setState(() {
        _emailError = emailError;
        _passwordError = passwordError;
        _error = null;
      });
      return;
    }

    if (_registering) {
      if (await _sendSignupCode() && mounted) {
        setState(() {
          _code.clear();
          _codeSentTo = email;
        });
      }
    } else if (await _run(() => ref.read(accountProvider.notifier).login(email, password)) && mounted) {
      _signedIn(email);
    }
  }

  /// Emails the sign-up code (again); true if that worked.
  Future<bool> _sendSignupCode() {
    final l = context.l10n;
    return _run(
      () => ref.read(apiClientProvider).startRegistration(_email.text.trim(), _password.text, language: l.localeName),
      onField: (e) {
        if (e is ApiException && e.code == 'invalid_input') {
          setState(() => _emailError = l.errorInvalidEmail);
          return true;
        }
        return false;
      },
    );
  }

  Future<void> _confirmCode() async {
    final l = context.l10n;
    final email = _codeSentTo!;
    final code = sixDigits(_code);
    if (code == null) {
      setState(() => _codeError = l.errorCodeDigits);
      return;
    }
    final done = await _run(
      () => ref.read(accountProvider.notifier).confirmRegistration(email, code),
      onField: (e) {
        if (e is ApiException && e.code == 'invalid_code') {
          setState(() => _codeError = l.errorInvalidCode);
          return true;
        }
        return false;
      },
    );
    if (done && mounted) _signedIn(email);
  }

  /// Back from the code step to the form, e.g. to fix a typo in the email.
  void _backToForm() => setState(() {
    _codeSentTo = null;
    _codeError = null;
    _error = null;
  });

  void _switchMode() => setState(() {
    _registering = !_registering;
    _emailError = null;
    _passwordError = null;
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final codeSentTo = _codeSentTo;
    return PopScope(
      // Back on the code step goes back to the form, not out of the screen.
      canPop: codeSentTo == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToForm();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(codeSentTo != null ? l.confirmEmailTitle : (_registering ? l.registerTitle : l.signInTitle)),
        ),
        body: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Kept in place (only hidden) during the code step, so the
              // password manager still sees the email and password when the
              // account is finally created, and offers to save them.
              Offstage(offstage: codeSentTo != null, child: _form(l)),
              if (codeSentTo != null) _codeStep(l, codeSentTo),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form(AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(l.email),
        EmailField(controller: _email, autofocus: true, error: _emailError),
        const SizedBox(height: 20),
        FieldLabel(l.password),
        PasswordField(
          controller: _password,
          isNew: _registering,
          rule: _registering ? l.passwordRule : null,
          error: _passwordError,
          onSubmitted: _busy ? null : _submit,
        ),
        if (!_registering)
          Align(
            alignment: Alignment.centerRight,
            child: TextLink(
              l.forgotPassword,
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => ResetPasswordScreen(email: _email.text.trim()))),
            ),
          ),
        if (_codeSentTo == null) ErrorBanner(_error),
        const SizedBox(height: 20),
        PrimaryButton(
          label: _busy ? l.pleaseWait : (_registering ? l.registerButton : l.signInButton),
          onPressed: _busy ? null : _submit,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _registering ? l.haveAccount : l.noAccountYet,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            TextLink(_registering ? l.signInLink : l.registerLink, onPressed: _busy ? null : _switchMode),
          ],
        ),
      ],
    );
  }

  Widget _codeStep(AppLocalizations l, String sentTo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.codeSentTo(sentTo), style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        const SizedBox(height: 24),
        FieldLabel(l.code),
        CodeField(controller: _code, error: _codeError, onSubmitted: _busy ? null : _confirmCode),
        ErrorBanner(_error),
        const SizedBox(height: 20),
        PrimaryButton(label: _busy ? l.pleaseWait : l.confirmButton, onPressed: _busy ? null : _confirmCode),
        const SizedBox(height: 12),
        ResendCodeLink(onResend: _sendSignupCode, enabled: !_busy),
        Center(child: TextLink(l.changeEmail, onPressed: _busy ? null : _backToForm)),
      ],
    );
  }
}
