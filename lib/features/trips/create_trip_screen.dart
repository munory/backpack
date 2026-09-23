import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/input_decoration.dart';
import '../../common/primary_button.dart';
import '../../common/theme.dart';
import '../../data/providers.dart';

/// Manual "start a named trip" form, shown on the Trips tab when there's no
/// active trip yet. Not a launch gate — packing gear from the Gear list
/// auto-creates an unnamed/untargeted trip without ever showing this form.
class CreateTripScreen extends ConsumerStatefulWidget {
  const CreateTripScreen({super.key});

  @override
  ConsumerState<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends ConsumerState<CreateTripScreen> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  String? _error;

  bool get _canSubmit => _nameController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onFieldsChanged);
    _targetController.addListener(_onFieldsChanged);
  }

  void _onFieldsChanged() => setState(() {});

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Введи название похода');
      return;
    }

    final targetKg = double.tryParse(_targetController.text.replaceAll(',', '.'));
    final targetGrams = (targetKg != null && targetKg > 0) ? (targetKg * 1000).round() : null;

    final db = ref.read(databaseProvider);
    await db.createTrip(name, targetGrams);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.backpack, size: 72, color: AppColors.accent),
            const SizedBox(height: 16),
            const Text(
              'Новый поход',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Дай походу имя. Целевой вес можно задать сейчас или позже.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            const FieldLabel('Название похода'),
            SizedBox(
              height: kFieldHeight,
              child: TextField(
                controller: _nameController,
                decoration: appFieldDecoration(),
              ),
            ),
            const SizedBox(height: 16),
            const FieldLabel('Целевой вес рюкзака, кг (необязательно)'),
            SizedBox(
              height: kFieldHeight,
              child: TextField(
                controller: _targetController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: appFieldDecoration(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.overWeight)),
            ],
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Создать поход',
              onPressed: _canSubmit ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}
