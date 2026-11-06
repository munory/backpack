import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/account_provider.dart';
import '../../common/input_decoration.dart';
import '../../common/l10n.dart';
import '../../common/theme.dart';
import 'account_fields.dart';

/// "Как к тебе обращаться": sets, changes or clears the optional name. The
/// only thing the app ever asks about a person besides the email.
Future<void> editAccountName(BuildContext context, String? current) => showDialog<void>(
  context: context,
  builder: (_) => _NameDialog(current: current),
);

class _NameDialog extends ConsumerStatefulWidget {
  const _NameDialog({required this.current});

  final String? current;

  @override
  ConsumerState<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends ConsumerState<_NameDialog> {
  late final _name = TextEditingController(text: widget.current ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    final name = _name.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(accountProvider.notifier).updateName(name.isEmpty ? null : name);
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (mounted) setState(() => _error = accountErrorText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.displayName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: kFieldHeight,
            child: TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: _busy ? null : (_) => _save(),
              autofillHints: const [AutofillHints.givenName],
              inputFormatters: [LengthLimitingTextInputFormatter(100)],
              decoration: appFieldDecoration(hint: l.nameHint),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(l.nameOptional, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          ErrorBanner(_error),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                child: Text(l.cancel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                onPressed: _busy ? null : _save,
                child: Text(_busy ? l.pleaseWait : l.save),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
