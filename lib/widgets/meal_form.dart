import 'package:flutter/material.dart';

class MealFormData {
  final String foodName;
  final double consumedG;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String mealType;
  final int foodId;
  final Map<String, double>? per100g;

  MealFormData({
    required this.foodName,
    required this.consumedG,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.mealType,
    this.foodId = 0,
    this.per100g,
  });
}

const List<String> _mealTypes = [
  'Breakfast', 'Brunch', 'Lunch', 'Dinner', 'Supper', 'Snack'
];

Future<MealFormData?> showMealForm(
  BuildContext context, {
  String title = 'Add Food',
  String submitLabel = 'Add',
  MealFormData? initial,
}) {
  return showModalBottomSheet<MealFormData>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1A1A1A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _MealFormSheet(
      title: title, submitLabel: submitLabel, initial: initial,
    ),
  );
}

class _MealFormSheet extends StatefulWidget {
  final String title;
  final String submitLabel;
  final MealFormData? initial;
  const _MealFormSheet({
    required this.title, required this.submitLabel, this.initial,
  });

  @override
  State<_MealFormSheet> createState() => _MealFormSheetState();
}

class _MealFormSheetState extends State<_MealFormSheet> {
  late TextEditingController _name, _grams, _protein, _carbs, _fat;
  late String _mealType;
  late bool _isScaleMode;   // scaling an existing quantity vs. creating a custom food
  late bool _nameLocked;
  late int _foodId;
  Map<String, double>? _per100g;

  double _r100Cals = 0, _r100Pro = 0, _r100Carb = 0, _r100Fat = 0;
  double _cCals = 0, _cPro = 0, _cCarb = 0, _cFat = 0;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _foodId = i?.foodId ?? 0;
    _per100g = i?.per100g;
    // Scale mode whenever we have an existing quantity to scale from.
    // (Creating a new custom food passes consumedG = 0 → editable macros.)
    _isScaleMode = (i?.consumedG ?? 0) > 0;
    // Lock the name for real database foods; allow editing for customs.
    _nameLocked = _isScaleMode && _foodId != 0;
    _mealType = i?.mealType ?? 'Lunch';

    _name = TextEditingController(text: i?.foodName ?? '');
    _grams = TextEditingController(
        text: (i != null && i.consumedG > 0) ? i.consumedG.toStringAsFixed(0) : '');

    if (_isScaleMode) {
      if (_per100g != null) {
        _r100Cals = _per100g!['calories'] ?? 0;
        _r100Pro  = _per100g!['protein'] ?? 0;
        _r100Carb = _per100g!['carbs'] ?? 0;
        _r100Fat  = _per100g!['fat'] ?? 0;
      } else {
        final g = i!.consumedG; // > 0 guaranteed by _isScaleMode
        _r100Cals = i.calories * 100 / g;
        _r100Pro  = i.protein  * 100 / g;
        _r100Carb = i.carbs    * 100 / g;
        _r100Fat  = i.fat      * 100 / g;
      }
      _protein = TextEditingController();
      _carbs   = TextEditingController();
      _fat     = TextEditingController();
      _recalc();
    } else {
      _protein = TextEditingController(text: i != null ? i.protein.toStringAsFixed(1) : '');
      _carbs   = TextEditingController(text: i != null ? i.carbs.toStringAsFixed(1)   : '');
      _fat     = TextEditingController(text: i != null ? i.fat.toStringAsFixed(1)     : '');
    }
  }

  @override
  void dispose() {
    _name.dispose(); _grams.dispose();
    _protein.dispose(); _carbs.dispose(); _fat.dispose();
    super.dispose();
  }

  void _recalc() {
    final mult = (double.tryParse(_grams.text) ?? 0) / 100.0;
    setState(() {
      _cCals = _r100Cals * mult;
      _cPro  = _r100Pro  * mult;
      _cCarb = _r100Carb * mult;
      _cFat  = _r100Fat  * mult;
    });
  }

  double get _customCals {
    final p = double.tryParse(_protein.text) ?? 0;
    final c = double.tryParse(_carbs.text) ?? 0;
    final f = double.tryParse(_fat.text) ?? 0;
    return p * 4 + c * 4 + f * 9;
  }

  void _submit() {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a food name.')));
      return;
    }
    final g = double.tryParse(_grams.text) ?? 0;

    if (_isScaleMode) {
      if (g <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a quantity.')));
        return;
      }
      Navigator.pop(context, MealFormData(
        foodName: _name.text.trim(),
        consumedG: g,
        calories: double.parse(_cCals.toStringAsFixed(1)),
        protein:  double.parse(_cPro.toStringAsFixed(1)),
        carbs:    double.parse(_cCarb.toStringAsFixed(1)),
        fat:      double.parse(_cFat.toStringAsFixed(1)),
        mealType: _mealType,
        foodId: _foodId,
        per100g: _per100g,
      ));
    } else {
      Navigator.pop(context, MealFormData(
        foodName: _name.text.trim(),
        consumedG: g,
        calories: double.parse(_customCals.toStringAsFixed(1)),
        protein:  double.tryParse(_protein.text) ?? 0,
        carbs:    double.tryParse(_carbs.text) ?? 0,
        fat:      double.tryParse(_fat.text) ?? 0,
        mealType: _mealType,
        foodId: 0,
      ));
    }
  }

  Widget _macroInput(String label, TextEditingController c, Color color) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label, labelStyle: TextStyle(color: color), suffixText: 'g',
        filled: true, fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _readChip(String label, double val, String unit, Color color) {
    return Column(children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      const SizedBox(height: 2),
      Text('${val.toStringAsFixed(unit == 'kcal' ? 0 : 1)}$unit',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              _isScaleMode
                  ? 'Macros scale with quantity.'
                  : 'Custom food — calories computed from macros. '
                    'Enter a quantity to save it for reuse.',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              enabled: !_nameLocked,
              decoration: InputDecoration(
                labelText: 'Food name',
                filled: true, fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _grams,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) {
                if (_isScaleMode) {
                  _recalc();
                } else {
                  setState(() {});
                }
              },
              decoration: InputDecoration(
                labelText: 'Quantity', suffixText: 'g',
                filled: true, fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            if (_isScaleMode) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _readChip('Calories', _cCals, 'kcal', Colors.orangeAccent),
                    _readChip('Protein', _cPro, 'g', Colors.tealAccent),
                    _readChip('Carbs', _cCarb, 'g', Colors.lightBlueAccent),
                    _readChip('Fat', _cFat, 'g', Colors.pinkAccent),
                  ],
                ),
              ),
            ] else ...[
              Row(children: [
                Expanded(child: _macroInput('Protein', _protein, Colors.tealAccent)),
                const SizedBox(width: 12),
                Expanded(child: _macroInput('Carbs', _carbs, Colors.lightBlueAccent)),
              ]),
              const SizedBox(height: 12),
              _macroInput('Fat', _fat, Colors.pinkAccent),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Calories (from macros)',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text('${_customCals.toStringAsFixed(0)} kcal',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold,
                            color: Colors.orangeAccent)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(children: [
              const Text('Meal: ', style: TextStyle(color: Colors.grey)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _mealType,
                dropdownColor: const Color(0xFF1E1E1E),
                items: _mealTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _mealType = v!),
              ),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent, foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(widget.submitLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}