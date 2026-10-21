import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/input_decoration.dart';
import '../../common/l10n.dart';
import '../../common/primary_button.dart';
import '../../common/text_format.dart';
import '../../common/theme.dart';
import '../../common/weight_format.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// Create a trip, or edit one when [editing] is set. Creating can start
/// from a copy of an existing trip's list ("Начать с"), since most trips
/// reuse most of the last one's gear. Editing a draft is "Превратить в
/// поход": it reads as creating a new trip (empty name, "Создать поход"),
/// keeping the draft's list.
class TripFormScreen extends ConsumerStatefulWidget {
  const TripFormScreen({super.key, this.editing});

  final Trip? editing;

  @override
  ConsumerState<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends ConsumerState<TripFormScreen> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  int? _copyFromTripId;

  bool get _canSubmit => _nameController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      if (!editing.isDraft) _nameController.text = editing.name;
      final target = editing.targetWeightGrams;
      // initState can't read the language yet — prefilled in
      // didChangeDependencies instead.
      _initialTargetGrams = target;
      _startDate = editing.startDate;
      _endDate = editing.endDate;
    }
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  int? _initialTargetGrams;

  /// What the target field was prefilled with — left untouched, the exact
  /// stored grams are kept instead of the rounded value shown.
  String? _initialTargetText;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialTargetGrams case final grams? when _initialTargetText == null) {
      _initialTargetText = formatInputNumber(
        grams / gramsPerBigUnit(weightUnitOf(context)),
        languageCode: context.l10n.localeName,
      );
      _targetController.text = _initialTargetText!;
    }
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      helpText: context.l10n.tripDates,
    );
    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
    }
  }

  Future<void> _submit() async {
    final name = capitalizeFirst(_nameController.text.trim());
    final target = parseInputNumber(_targetController.text);
    final targetGrams = _targetController.text == _initialTargetText
        ? _initialTargetGrams
        : (target != null && target > 0)
            ? (target * gramsPerBigUnit(weightUnitOf(context))).round()
            : null;
    final db = ref.read(databaseProvider);
    final editing = widget.editing;

    if (editing == null) {
      await db.createTrip(
        name: name,
        targetWeightGrams: targetGrams,
        startDate: _startDate,
        endDate: _endDate,
        copyFromTripId: _copyFromTripId,
      );
    } else {
      await db.updateTrip(
        id: editing.id,
        name: name,
        targetWeightGrams: targetGrams,
        startDate: _startDate,
        endDate: _endDate,
        isDraft: false,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editing != null && !widget.editing!.isDraft;
    final isCreating = widget.editing == null;
    final trips = ref.watch(tripsProvider).value ?? const <Trip>[];
    final l = context.l10n;
    final dates = formatTripDates(_startDate, _endDate, languageCode: l.localeName);

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? l.editTrip : l.newTrip)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FieldLabel(l.name),
          SizedBox(
            height: kFieldHeight,
            child: TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: appFieldDecoration(hint: l.tripNameHint),
            ),
          ),
          const SizedBox(height: 20),
          FieldLabel(l.datesOptional),
          InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: _pickDates,
            child: Container(
              height: kFieldHeight,
              padding: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      dates ?? l.pickDates,
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                            color: dates == null
                                ? AppColors.textSecondary.withValues(alpha: 0.6)
                                : AppColors.textPrimary,
                          ),
                    ),
                  ),
                  if (dates != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: l.clearDates,
                      onPressed: () => setState(() {
                        _startDate = null;
                        _endDate = null;
                      }),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(Icons.calendar_today_outlined,
                          size: 18, color: AppColors.textPrimary.withValues(alpha: 0.6)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FieldLabel(l.targetOptional(bigUnitLabel(l, weightUnitOf(context)))),
          SizedBox(
            height: kFieldHeight,
            child: TextField(
              controller: _targetController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: appFieldDecoration(),
            ),
          ),
          if (isCreating && trips.isNotEmpty) ...[
            const SizedBox(height: 20),
            FieldLabel(l.startFrom),
            AppSelectField<int?>(
              value: _copyFromTripId,
              onChanged: (v) => setState(() => _copyFromTripId = v),
              options: [
                SelectOption(null, l.emptyList),
                for (final t in trips) SelectOption(t.id, l.listOfTrip(tripName(l, t))),
              ],
            ),
          ],
          const SizedBox(height: 32),
          PrimaryButton(
            label: isEditing ? l.save : l.createTrip,
            onPressed: _canSubmit ? _submit : null,
          ),
        ],
      ),
    );
  }
}
