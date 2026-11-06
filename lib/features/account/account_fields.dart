import 'package:flutter/material.dart';

import '../../account/api_client.dart';
import '../../common/input_decoration.dart';
import '../../common/l10n.dart';
import '../../common/theme.dart';

/// The fewest characters the server accepts in a password.
const minPasswordLength = 8;

/// Good enough to catch typos before asking the server; the server checks
/// properly.
bool looksLikeEmail(String text) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text.trim());

/// What went wrong, in words — for a server refusal, no connection, or
/// anything else.
String accountErrorText(AppLocalizations l, Object error) {
  if (error is NetworkException) return l.errorNoConnection;
  if (error is! ApiException) return l.errorGeneric;
  return switch (error.code) {
    'invalid_credentials' => l.errorInvalidCredentials,
    'email_taken' => l.errorEmailTaken,
    'invalid_code' => l.errorInvalidCode,
    'wrong_password' => l.errorWrongPassword,
    'too_many_requests' => l.errorTooManyAttempts,
    'mail_not_configured' || 'mail_failed' => l.errorMailUnavailable,
    'invalid_input' => l.errorInvalidEmail,
    _ => l.errorGeneric,
  };
}

/// An email field that password managers recognise: they offer the saved
/// address here, and pair it with the password field next to it.
class EmailField extends StatelessWidget {
  const EmailField({super.key, required this.controller, this.onSubmitted, this.autofocus = false, this.error});

  final TextEditingController controller;
  final VoidCallback? onSubmitted;
  final bool autofocus;

  /// What's wrong with what's typed — shown under the field, outlined red.
  final String? error;

  @override
  Widget build(BuildContext context) {
    final field = SizedBox(
      height: kFieldHeight,
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: onSubmitted == null ? TextInputAction.next : TextInputAction.done,
        onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
        // "This is the account name" — what password managers key on.
        autofillHints: const [AutofillHints.email, AutofillHints.username],
        decoration: withError(appFieldDecoration(hint: 'you@example.com'), error),
      ),
    );
    return FieldWithNote(field: field, error: error);
  }
}

/// A password field with an eye to show what's typed. [isNew] marks a
/// password being chosen (sign-up, reset): password managers then offer to
/// generate a strong one and save it, instead of filling in the old one.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.isNew = false,
    this.rule,
    this.error,
    this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final bool isNew;

  /// A small line under the field ("at least 8 characters") — a hint inside
  /// the field would vanish at the first letter typed.
  final String? rule;

  /// What's wrong with it — shown in place of [rule], outlined red.
  final String? error;
  final VoidCallback? onSubmitted;
  final bool autofocus;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final field = SizedBox(
      height: kFieldHeight,
      child: TextField(
        controller: widget.controller,
        autofocus: widget.autofocus,
        obscureText: !_visible,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.done,
        onSubmitted: widget.onSubmitted == null ? null : (_) => widget.onSubmitted!(),
        autofillHints: [widget.isNew ? AutofillHints.newPassword : AutofillHints.password],
        decoration: withError(appFieldDecoration(), widget.error).copyWith(
          suffixIcon: IconButton(
            tooltip: _visible ? l.hidePassword : l.showPassword,
            icon: Icon(
              _visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 20,
              color: AppColors.textPrimary.withValues(alpha: 0.6),
            ),
            onPressed: () => setState(() => _visible = !_visible),
          ),
        ),
      ),
    );
    return FieldWithNote(field: field, error: widget.error, note: widget.rule);
  }
}

/// [decoration] outlined red when there's an [error].
InputDecoration withError(InputDecoration decoration, String? error) {
  if (error == null) return decoration;
  final red = OutlineInputBorder(borderSide: BorderSide(color: AppColors.overWeight));
  return decoration.copyWith(
    enabledBorder: red,
    focusedBorder: red.copyWith(borderSide: BorderSide(color: AppColors.overWeight, width: 1.5)),
  );
}

/// A field with a small line under it: the [error] in red if there is one,
/// else a grey [note] ("at least 8 characters"), else nothing. Errors about
/// one field go here, right where the fix is; errors about the form as a
/// whole go in an [ErrorBanner].
class FieldWithNote extends StatelessWidget {
  const FieldWithNote({super.key, required this.field, this.error, this.note});

  final Widget field;
  final String? error;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final text = error ?? note;
    if (text == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field,
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 2),
          child: Text(
            text,
            style: TextStyle(color: error != null ? AppColors.overWeight : AppColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

/// What went wrong with the form as a whole — the server said no, no
/// connection — in a soft red box with an icon, just above the button, where
/// the eye is at the moment of pressing it. Nothing when [text] is null.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.text, {super.key});

  final String? text;

  @override
  Widget build(BuildContext context) {
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.overWeight.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 20, color: AppColors.overWeight),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text!, style: TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.35)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A plain text link in the accent color: "Не помню пароль", "Войти".
class TextLink extends StatelessWidget {
  const TextLink(this.label, {super.key, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 40),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}
