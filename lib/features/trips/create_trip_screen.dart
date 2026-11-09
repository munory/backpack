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

/// Creates a trip or, with [editing] set, opens one. Creating can start from
/// a copy of an existing trip's list ("Начать с"), since most trips reuse
/// most of the last one's gear.
///
/// An opened trip is edited here — name, dates, target — and "⋯" duplicates
/// or deletes it. Choosing which trip is on Главная is the trip card's
/// "Выбрать", not this screen's.
///
/// The draft becomes a real trip once it's given a name.
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

  Trip? get _editing => widget.editing;
  bool get _isDraft => _editing?.isDraft ?? false;
  String get _name => _nameController.text.trim();

  /// A trip needs a name; the draft may stay nameless (it stays a draft).
  bool get _nameOk => _name.isNotEmpty || _isDraft;

  /// Something here differs from what's saved.
  bool get _dirty {
    final editing = _editing;
    if (editing == null) return false;
    return _name != (editing.isDraft ? '' : editing.name) ||
        _startDate != editing.startDate ||
        _endDate != editing.endDate ||
        _targetController.text != (_initialTargetText ?? '');
  }

  @override
  void initState() {
    super.initState();
    final editing = _editing;
    if (editing != null) {
      if (!editing.isDraft) _nameController.text = editing.name;
      // initState can't read the language yet — prefilled in
      // didChangeDependencies instead.
      _initialTargetGrams = editing.targetWeightGrams;
      _startDate = editing.startDate;
      _endDate = editing.endDate;
    }
    _nameController.addListener(() => setState(() {}));
    _targetController.addListener(() => setState(() {}));
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

  int? get _targetGrams {
    final target = parseInputNumber(_targetController.text);
    if (_targetController.text == _initialTargetText) return _initialTargetGrams;
    return (target != null && target > 0) ? (target * gramsPerBigUnit(weightUnitOf(context))).round() : null;
  }

  Future<void> _create() async {
    await ref.read(databaseProvider).createTrip(
          name: capitalizeFirst(_name),
          targetWeightGrams: _targetGrams,
          startDate: _startDate,
          endDate: _endDate,
          copyFromTripId: _copyFromTripId,
        );
    if (mounted) Navigator.pop(context);
  }

  /// Saves the edits. A named draft becomes a trip; a nameless one stays
  /// the draft.
  Future<void> _save() async {
    final editing = _editing!;
    final named = _name.isNotEmpty;
    await ref.read(databaseProvider).updateTrip(
          id: editing.id,
          name: named ? capitalizeFirst(_name) : editing.name,
          targetWeightGrams: _targetGrams,
          startDate: _startDate,
          endDate: _endDate,
          isDraft: named ? false : null,
        );
  }

  Future<void> _saveAndClose() async {
    await _save();
    if (mounted) Navigator.pop(context);
  }

  /// Back with unsaved edits: save them, drop them, or stay.
  Future<void> _confirmLeave() async {
    final l = context.l10n;
    final choice = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.saveChangesTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: Text(l.dontSave),
          ),
          FilledButton(
            onPressed: _nameOk ? () => Navigator.pop(context, true) : null,
            child: Text(l.save),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    if (choice) await _save();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _onMenu(String action) async {
    final editing = _editing!;
    switch (action) {
      case 'duplicate':
        await duplicateTripAndOpen(context, ref, editing, replace: true);
      case 'delete':
        if (await confirmDeleteTrip(context, editing)) {
          await ref.read(databaseProvider).deleteTrip(editing.id);
          if (mounted) Navigator.pop(context);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = _editing;
    final trips = ref.watch(tripsProvider).value ?? const <Trip>[];
    final l = context.l10n;
    final dates = formatTripDates(_startDate, _endDate, languageCode: l.localeName);
    final dirty = _dirty;

    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(editing == null ? l.newTrip : tripName(l, editing)),
          actions: [
            if (editing != null)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz),
                tooltip: l.moreActions,
                onSelected: _onMenu,
                itemBuilder: (_) => [
                  if (!editing.isDraft) PopupMenuItem(value: 'duplicate', child: Text(l.duplicate)),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(l.delete, style: TextStyle(color: AppColors.overWeight)),
                  ),
                ],
              ),
          ],
        ),
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
            if (_isDraft) ...[
              const SizedBox(height: 6),
              Text(l.draftNameNote, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
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
            if (editing == null && trips.isNotEmpty) ...[
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
            if (editing == null)
              PrimaryButton(label: l.createTrip, onPressed: _name.isNotEmpty ? _create : null)
            else
              PrimaryButton(label: l.save, onPressed: dirty && _nameOk ? _saveAndClose : null),
          ],
        ),
      ),
    );
  }
}

/// A copy of [trip], with the same list, named "X (копия)"; it becomes the
/// active trip. Opens straight into it: a copy almost always needs a new
/// name or dates. With [replace], it takes the place of the current screen.
Future<void> duplicateTripAndOpen(BuildContext context, WidgetRef ref, Trip trip, {bool replace = false}) async {
  final db = ref.read(databaseProvider);
  final id = await db.duplicateTrip(trip, copyWord: context.l10n.copyWord);
  final copy = await (db.select(db.trips)..where((t) => t.id.equals(id))).getSingle();
  if (!context.mounted) return;
  final route = MaterialPageRoute<void>(builder: (_) => TripFormScreen(editing: copy));
  if (replace) {
    Navigator.of(context).pushReplacement(route);
  } else {
    Navigator.of(context).push(route);
  }
}

/// "Delete Карелия?" — true if confirmed.
Future<bool> confirmDeleteTrip(BuildContext context, Trip trip) async {
  final l = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.deleteTripTitle(tripName(l, trip))),
      content: Text(l.deleteTripBody, style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                child: Text(l.cancel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.overWeight),
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.delete),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return ok ?? false;
}
