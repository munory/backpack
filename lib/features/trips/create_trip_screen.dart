import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/input_decoration.dart';
import '../../common/primary_button.dart';
import '../../common/text_format.dart';
import '../../common/theme.dart';
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
      if (target != null) _targetController.text = _formatKgInput(target);
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

  String _formatKgInput(int grams) {
    final kg = grams / 1000;
    return kg == kg.roundToDouble() ? kg.round().toString() : kg.toString();
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
      helpText: 'Даты похода',
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
    final targetKg = double.tryParse(_targetController.text.replaceAll(',', '.'));
    final targetGrams = (targetKg != null && targetKg > 0) ? (targetKg * 1000).round() : null;
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
    final dates = formatTripDates(_startDate, _endDate);

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Редактировать поход' : 'Новый поход')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const FieldLabel('Название'),
          SizedBox(
            height: kFieldHeight,
            child: TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: appFieldDecoration(hint: 'Например, Карелия на выходные'),
            ),
          ),
          const SizedBox(height: 20),
          const FieldLabel('Даты (необязательно)'),
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
                      dates ?? 'Выбрать даты',
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
                      tooltip: 'Убрать даты',
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
          const FieldLabel('Целевой вес рюкзака, кг (необязательно)'),
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
            const FieldLabel('Начать с'),
            AppSelectField<int?>(
              value: _copyFromTripId,
              onChanged: (v) => setState(() => _copyFromTripId = v),
              options: [
                const SelectOption(null, 'Пустой список'),
                for (final t in trips) SelectOption(t.id, 'Список похода «${t.name}»'),
              ],
            ),
          ],
          const SizedBox(height: 32),
          PrimaryButton(
            label: isEditing ? 'Сохранить' : 'Создать поход',
            onPressed: _canSubmit ? _submit : null,
          ),
        ],
      ),
    );
  }
}
