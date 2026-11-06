import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common/input_decoration.dart';
import '../../common/l10n.dart';
import '../../common/theme.dart';
import 'account_fields.dart';

/// How long before another code may be asked for — the server sends at most
/// one a minute anyway (a second ask inside the minute is quietly ignored,
/// and the code already sent keeps working).
const resendWait = Duration(seconds: 60);

/// The field for a 6-digit code from an email: digits only, at most six,
/// spaced out to read like the email shows it.
class CodeField extends StatelessWidget {
  const CodeField({super.key, required this.controller, this.error, this.onSubmitted});

  final TextEditingController controller;
  final String? error;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return FieldWithNote(
      error: error,
      field: SizedBox(
        height: kFieldHeight,
        child: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: onSubmitted == null ? TextInputAction.next : TextInputAction.done,
          onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
          // Lets the keyboard offer the code straight from the email
          // notification, where the phone supports it.
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          style: const TextStyle(letterSpacing: 4),
          decoration: withError(appFieldDecoration(hint: '000000'), error),
        ),
      ),
    );
  }
}

/// The digits typed into a [CodeField], or null if there aren't six.
String? sixDigits(TextEditingController controller) {
  final code = controller.text.replaceAll(RegExp(r'\s'), '');
  return code.length == 6 ? code : null;
}

/// "Отправить снова через 59 с" counting down from the moment it appears
/// (a code was just sent), then a "send the code again" link. [onResend]
/// sends it and says whether that worked — the countdown restarts if so.
class ResendCodeLink extends StatefulWidget {
  const ResendCodeLink({super.key, required this.onResend, this.enabled = true});

  final Future<bool> Function() onResend;
  final bool enabled;

  @override
  State<ResendCodeLink> createState() => _ResendCodeLinkState();
}

class _ResendCodeLinkState extends State<ResendCodeLink> {
  Timer? _ticker;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    _ticker?.cancel();
    setState(() => _secondsLeft = resendWait.inSeconds);
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: _secondsLeft > 0
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(l.resendIn('$_secondsLeft'), style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            )
          : TextLink(
              l.resendCode,
              onPressed: widget.enabled
                  ? () async {
                      if (await widget.onResend() && mounted) _start();
                    }
                  : null,
            ),
    );
  }
}
