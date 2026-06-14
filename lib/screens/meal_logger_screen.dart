import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../diary_db.dart';
import '../services/api_service.dart';
import '../services/goals_service.dart';
import '../widgets/meal_form.dart';
import '../widgets/food_picker.dart';
import '../services/settings_service.dart';

class MealLoggerScreen extends StatefulWidget {
  const MealLoggerScreen({super.key});

  @override
  State<MealLoggerScreen> createState() => _MealLoggerScreenState();
}

class _MealLoggerScreenState extends State<MealLoggerScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextEditingController _textController = TextEditingController();

  bool _isListening = false;
  String _spokenText = '';
  String _selectedMealType = 'Lunch';
  bool _isLoading = false;

  List<Map<String, dynamic>> _todayMeals = [];
  List<Map<String, dynamic>> _favorites = [];
  Map<String, double> _totals = {
    'calories': 0.0, 'protein': 0.0, 'carbs': 0.0, 'fat': 0.0
  };
  Map<String, double> _goals = {
    'calories': 0.0, 'protein': 0.0, 'carbs': 0.0, 'fat': 0.0
  };
  Map<String, double> _yesterday = {
    'calories': 0.0, 'protein': 0.0, 'carbs': 0.0, 'fat': 0.0
  };

  static const List<String> _mealOrder = [
    'Breakfast', 'Brunch', 'Lunch', 'Dinner', 'Supper', 'Snack'
  ];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _refreshLog();
    _loadFavorites();
    _loadYesterday();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _initSpeech() async {
    await Permission.microphone.request();
    await _speech.initialize(
      onError: (val) => print('Speech Error: $val'),
      onStatus: (val) {
        if ((val == 'done' || val == 'notListening') && _isListening) {
          setState(() => _isListening = false);
          if (_spokenText.isNotEmpty) _submitNetworkEntry(_spokenText);
        }
      },
    );
  }

  String _getTodayYMD() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  String _getYesterdayYMD() {
    final y = DateTime.now().subtract(const Duration(days: 1));
    return '${y.year}-${y.month.toString().padLeft(2, '0')}-${y.day.toString().padLeft(2, '0')}';
  }

  Future<void> _refreshLog() async {
    final today  = _getTodayYMD();
    final data   = await DiaryDatabase.instance.getMealsByDate(today);
    final totals = await DiaryDatabase.instance.getDailyTotals(today);
    final goals  = await GoalsService.getGoals();
    setState(() {
      _todayMeals = data;
      _totals = totals;
      _goals  = goals;
    });
  }

  Future<void> _loadYesterday() async {
    final totals = await DiaryDatabase.instance.getDailyTotals(_getYesterdayYMD());
    setState(() => _yesterday = totals);
  }

  void _listen() async {
    if (!_isListening) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (val) => setState(() => _spokenText = val.recognizedWords),
        listenFor: const Duration(seconds: 30),
        pauseFor:  const Duration(seconds: 5),
        listenMode: stt.ListenMode.dictation,
      );
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      if (_spokenText.isNotEmpty) _submitNetworkEntry(_spokenText);
    }
  }

  Future<void> _submitNetworkEntry(String rawText) async {
    setState(() {
      _isLoading = true;
      _spokenText = '';
      _textController.clear();
    });

    final clarifyEnabled = await SettingsService.getClarifyEnabled();
    final response = await ApiService.processMealVoice(
      rawText: rawText,
      mealType: _selectedMealType,
      clarify: clarifyEnabled,
    );

    if (response != null && response['success'] == true) {
      final List items = response['items'];
      final String effectiveMealType = response['meal_type'] as String;

      for (var item in items) {
        await DiaryDatabase.instance.insertMeal({
          'timestamp':      DateTime.now().toIso8601String(),
          'meal_type':      effectiveMealType,
          'food_id':        item['NDB_No'] ?? 0,
          'user_food_name': rawText,
          'food_name_full': item['Food_Name_Full'] ?? 'Unknown',
          'consumed_g':     item['Consumed_g']?.toDouble()     ?? 0.0,
          'calories':       item['Energy_kcal']?.toDouble()    ?? 0.0,
          'protein':        item['Protein_g']?.toDouble()      ?? 0.0,
          'carbs':          item['Carb_g']?.toDouble()         ?? 0.0,
          'fat':            item['Fat_g']?.toDouble()          ?? 0.0,
          'sugar_g':        item['Sugar_g']?.toDouble()        ?? 0.0,
          'fiber_g':        item['Fiber_g']?.toDouble()        ?? 0.0,
          'vita_mcg':       item['VitA_mcg']?.toDouble()       ?? 0.0,
          'vitb6_mg':       item['VitB6_mg']?.toDouble()       ?? 0.0,
          'vitb12_mcg':     item['VitB12_mcg']?.toDouble()     ?? 0.0,
          'vitc_mg':        item['VitC_mg']?.toDouble()        ?? 0.0,
          'vite_mg':        item['VitE_mg']?.toDouble()        ?? 0.0,
          'folate_mcg':     item['Folate_mcg']?.toDouble()     ?? 0.0,
          'niacin_mg':      item['Niacin_mg']?.toDouble()      ?? 0.0,
          'riboflavin_mg':  item['Riboflavin_mg']?.toDouble()  ?? 0.0,
          'thiamin_mg':     item['Thiamin_mg']?.toDouble()     ?? 0.0,
          'calcium_mg':     item['Calcium_mg']?.toDouble()     ?? 0.0,
          'copper_mcg':     item['Copper_mcg']?.toDouble()     ?? 0.0,
          'iron_mg':        item['Iron_mg']?.toDouble()        ?? 0.0,
          'magnesium_mg':   item['Magnesium_mg']?.toDouble()   ?? 0.0,
          'manganese_mg':   item['Manganese_mg']?.toDouble()   ?? 0.0,
          'phosphorus_mg':  item['Phosphorus_mg']?.toDouble()  ?? 0.0,
          'selenium_mcg':   item['Selenium_mcg']?.toDouble()   ?? 0.0,
          'zinc_mg':        item['Zinc_mg']?.toDouble()        ?? 0.0,
        });
      }
      setState(() => _selectedMealType = effectiveMealType);

      final skipped = List<String>.from(response['skipped_items'] ?? []);
      if (skipped.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('⚠️ Could not identify: ${skipped.join(', ')}'),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 5),
        ));
      }
    } else {
      if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ ${response['error_message'] ?? 'Processing failed.'}')),
    );
  }
}

    setState(() => _isLoading = false);
    _refreshLog();

    // Resolve any ambiguous items the backend flagged (after the spinner clears)
    if (response != null) {
      final clarifications =
          List<Map<String, dynamic>>.from(response['clarifications'] ?? []);
      for (final clar in clarifications) {
        await _resolveClarification(clar);
      }
    }
  }

  Future<void> _deleteEntry(int logId) async {
    await DiaryDatabase.instance.deleteMeal(logId);
    _refreshLog();
  }

  Future<void> _addFood() async {
  final pick = await showFoodPicker(context);
  if (pick == null) return;
  if (pick.isCustom) {
    await _addCustomFood();
  } else {
    await _addDatabaseFood(pick.food!);
  }
}

Future<void> _addDatabaseFood(Map<String, dynamic> food) async {
  final per100 = (food['per_100g'] as Map)
      .map((k, v) => MapEntry(k as String, (v as num).toDouble()));
  final result = await showMealForm(
    context,
    title: 'Add ${food['food_name_full']}',
    submitLabel: 'Log',
    initial: MealFormData(
      foodName:  food['food_name_full'] as String,
      consumedG: 100, // sensible default; user adjusts
      calories:  per100['calories'] ?? 0,
      protein:   per100['protein'] ?? 0,
      carbs:     per100['carbs'] ?? 0,
      fat:       per100['fat'] ?? 0,
      mealType:  _selectedMealType,
      foodId:    (food['ndb_no'] as num?)?.toInt() ?? 0,
      per100g:   per100,
    ),
  );
  if (result == null) return;

  final mult = result.consumedG / 100.0;
  final row = <String, dynamic>{
    'timestamp':      DateTime.now().toIso8601String(),
    'meal_type':      result.mealType,
    'food_id':        result.foodId,
    'user_food_name': result.foodName,
    'food_name_full': result.foodName,
    'consumed_g':     result.consumedG,
  };
  for (final col in DiaryDatabase.scalableColumns) {
    row[col] = (result.per100g?[col] ?? 0) * mult;
  }
  await DiaryDatabase.instance.insertMeal(row);
  _refreshLog();
}

Future<void> _resolveClarification(Map<String, dynamic> clar) async {
  final searchTerm = clar['search_term'] as String;
  final qty = (clar['qty_grams'] as num).toDouble();
  final groups = List<Map<String, dynamic>>.from(clar['groups'] ?? []);
  if (groups.isEmpty || !mounted) return;

  // Step 1 — pick the cut
  final chosenGroup = await _showClarifyStep(
    title: 'Which "$searchTerm"?',
    subtitle: '${qty.toStringAsFixed(0)}g — pick the cut',
    options: groups.map((g) {
      final rep = g['representative'] as Map<String, dynamic>;
      final cal100 =
          ((rep['per_100g'] as Map)['calories'] as num?)?.toDouble() ?? 0;
      return _ClarifyOption(
        title: g['group_label'] as String,
        kcalAtQty: cal100 * qty / 100,
        data: g,
        showChevron: g['needs_detail'] == true,
      );
    }).toList(),
  );
  if (chosenGroup == null) return; // skipped

  Map<String, dynamic> chosenFood;
  if (chosenGroup['needs_detail'] == true) {
    // Step 2 — pick the preparation (only when the cut's preps diverge)
    final preps =
        List<Map<String, dynamic>>.from(chosenGroup['preparations'] ?? []);
    final chosenPrep = await _showClarifyStep(
      title: chosenGroup['group_label'] as String,
      subtitle: '${qty.toStringAsFixed(0)}g — pick the preparation',
      options: preps.map((p) {
        final cal100 =
            ((p['per_100g'] as Map)['calories'] as num?)?.toDouble() ?? 0;
        return _ClarifyOption(
          title: p['food_name_full'] as String,
          kcalAtQty: cal100 * qty / 100,
          data: p,
        );
      }).toList(),
    );
    if (chosenPrep == null) return; // skipped at step 2
    chosenFood = chosenPrep;
  } else {
    chosenFood = chosenGroup['representative'] as Map<String, dynamic>;
  }

  await _logClarifiedFood(searchTerm, qty, chosenFood);
}

Future<Map<String, dynamic>?> _showClarifyStep({
  required String title,
  required String subtitle,
  required List<_ClarifyOption> options,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    backgroundColor: const Color(0xFF1A1A1A),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final o = options[i];
                  return ListTile(
                    dense: true,
                    title: Text(o.title, style: const TextStyle(fontSize: 14)),
                    subtitle: Text('${o.kcalAtQty.toStringAsFixed(0)} kcal',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                    trailing: o.showChevron
                        ? const Icon(Icons.chevron_right,
                            size: 18, color: Colors.grey)
                        : null,
                    onTap: () => Navigator.pop(ctx, o.data),
                  );
                },
              ),
            ),
            const Divider(color: Color(0xFF2A2A2A)),
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text("Skip — don't log this",
                  style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _logClarifiedFood(
    String searchTerm, double qty, Map<String, dynamic> food) async {
  final per100 = (food['per_100g'] as Map)
      .map((k, v) => MapEntry(k as String, (v as num).toDouble()));
  final mult = qty / 100.0;
  final row = <String, dynamic>{
    'timestamp':      DateTime.now().toIso8601String(),
    'meal_type':      _selectedMealType,
    'food_id': (food['ndb_no'] as num?)?.toInt() ?? 0,
    'user_food_name': searchTerm,
    'food_name_full': food['food_name_full'],
    'consumed_g':     qty,
  };
  for (final col in DiaryDatabase.scalableColumns) {
    row[col] = (per100[col] ?? 0) * mult;
  }
  await DiaryDatabase.instance.insertMeal(row);
  _refreshLog();
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logged $searchTerm')));
  }
}

Future<void> _addCustomFood() async {
  final result = await showMealForm(
    context,
    title: 'Create Custom Food',
    submitLabel: 'Save & Log',
    initial: MealFormData(
      foodName: '', consumedG: 0, calories: 0,
      protein: 0, carbs: 0, fat: 0, mealType: _selectedMealType,
    ),
  );
  if (result == null) return;

  int foodId = 0;
  // Need a quantity to derive a reusable per-100g profile
  if (result.consumedG > 0) {
    final to100 = 100.0 / result.consumedG;
    final resp = await ApiService.addCustomFood(
      foodName:   result.foodName,
      energyKcal: result.calories * to100,
      proteinG:   result.protein  * to100,
      carbG:      result.carbs    * to100,
      fatG:       result.fat      * to100,
    );
    if (resp['success'] == true) {
      foodId = (resp['ndb_no'] as num?)?.toInt() ?? 0;
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Logged, but couldn’t save for reuse: '
            '${resp['error_message'] ?? 'server error'}')));
    }
  }

  await DiaryDatabase.instance.insertMeal({
    'timestamp':      DateTime.now().toIso8601String(),
    'meal_type':      result.mealType,
    'food_id':        foodId,
    'user_food_name': result.foodName,
    'food_name_full': result.foodName,
    'consumed_g':     result.consumedG,
    'calories':       result.calories,
    'protein':        result.protein,
    'carbs':          result.carbs,
    'fat':            result.fat,
  });
  _refreshLog();
}

Future<void> _editEntry(Map<String, dynamic> item) async {
  final result = await showMealForm(
    context,
    title: 'Edit Entry',
    submitLabel: 'Save',
    initial: MealFormData(
      foodName:  item['food_name_full'] as String,
      consumedG: (item['consumed_g'] as num).toDouble(),
      calories:  (item['calories'] as num).toDouble(),
      protein:   (item['protein'] as num).toDouble(),
      carbs:     (item['carbs'] as num).toDouble(),
      fat:       (item['fat'] as num).toDouble(),
      mealType:  item['meal_type'] as String,
      foodId:    item['food_id'] as int,
    ),
  );
  if (result == null) return;

  final oldG = (item['consumed_g'] as num).toDouble();
  final updateFields = <String, dynamic>{
    'meal_type':  result.mealType,
    'consumed_g': result.consumedG,
  };

  if (oldG > 0) {
    // Scale ALL 23 nutrients by the quantity ratio — works for any food.
    final ratio = result.consumedG / oldG;
    for (final col in DiaryDatabase.scalableColumns) {
      final orig = (item[col] as num?)?.toDouble() ?? 0;
      updateFields[col] = orig * ratio;
    }
  } else {
    // Quantity-less custom entry: macros come straight from the form.
    updateFields['user_food_name'] = result.foodName;
    updateFields['food_name_full'] = result.foodName;
    updateFields['calories'] = result.calories;
    updateFields['protein']  = result.protein;
    updateFields['carbs']    = result.carbs;
    updateFields['fat']      = result.fat;
  }

  await DiaryDatabase.instance.updateMeal(item['log_id'] as int, updateFields);
  _refreshLog();
}

Future<void> _loadFavorites() async {
  final favs = await DiaryDatabase.instance.getFavorites();
  if (!mounted) return;
  setState(() => _favorites = favs);
}

Future<void> _favoriteEntry(Map<String, dynamic> item) async {
  final controller =
      TextEditingController(text: item['food_name_full'] as String);
  final label = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text('Save as favorite'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(labelText: 'Label'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save')),
      ],
    ),
  );
  if (label == null || label.isEmpty) return;

  final row = <String, dynamic>{
    'label':          label,
    'food_id':        item['food_id'] ?? 0,
    'food_name_full': item['food_name_full'],
    'consumed_g':     item['consumed_g'],
    'created_at':     DateTime.now().toIso8601String(),
  };
  for (final col in DiaryDatabase.scalableColumns) {
    row[col] = (item[col] as num?)?.toDouble() ?? 0;
  }
  await DiaryDatabase.instance.addFavorite(row);
  await _loadFavorites();
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved "$label" to favorites')));
  }
}

Future<void> _logFavorite(Map<String, dynamic> fav) async {
  final row = <String, dynamic>{
    'timestamp':      DateTime.now().toIso8601String(),
    'meal_type':      _selectedMealType,
    'food_id':        fav['food_id'] ?? 0,
    'user_food_name': fav['label'],
    'food_name_full': fav['food_name_full'],
    'consumed_g':     fav['consumed_g'],
  };
  for (final col in DiaryDatabase.scalableColumns) {
    row[col] = (fav[col] as num?)?.toDouble() ?? 0;
  }
  await DiaryDatabase.instance.insertMeal(row);
  _refreshLog();
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logged ${fav['label']}')));
  }
}

Future<void> _confirmDeleteFavorite(Map<String, dynamic> fav) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text('Remove "${fav['label']}"?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove')),
      ],
    ),
  );
  if (ok == true) {
    await DiaryDatabase.instance.deleteFavorite(fav['fav_id'] as int);
    await _loadFavorites();
  }
}

Future<void> _copyYesterday() async {
  final copied =
      await DiaryDatabase.instance.copyDayToToday(_getYesterdayYMD());
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(copied == 0
        ? 'No entries logged yesterday.'
        : 'Copied $copied entries from yesterday.'),
  ));
  _refreshLog();
}

  Map<String, List<Map<String, dynamic>>> _groupByMealType() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final meal in _todayMeals) {
      grouped.putIfAbsent(meal['meal_type'] as String, () => []).add(meal);
    }
    final sorted = <String, List<Map<String, dynamic>>>{};
    for (final t in _mealOrder) {
      if (grouped.containsKey(t)) sorted[t] = grouped[t]!;
    }
    for (final e in grouped.entries) {
      if (!sorted.containsKey(e.key)) sorted[e.key] = e.value;
    }
    return sorted;
  }

  bool get _hasGoals     => _goals.values.any((v) => v > 0);
  bool get _hasYesterday => (_yesterday['calories'] ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByMealType();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [

          // ── Today macro cards ──────────────────────────────
          Row(children: [
            Expanded(child: _buildMacroCard('Calories', _totals['calories']!.toStringAsFixed(0), 'kcal', Colors.orangeAccent)),
            Expanded(child: _buildMacroCard('Protein',  _totals['protein']!.toStringAsFixed(1),  'g',    Colors.tealAccent)),
            Expanded(child: _buildMacroCard('Carbs',    _totals['carbs']!.toStringAsFixed(1),    'g',    Colors.lightBlueAccent)),
            Expanded(child: _buildMacroCard('Fat',      _totals['fat']!.toStringAsFixed(1),      'g',    Colors.pinkAccent)),
          ]),

          // ── Goal progress bars ─────────────────────────────
          if (_hasGoals) ...[
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DAILY GOALS',
                        style: TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    _buildGoalBar('Cal',  _totals['calories']!, _goals['calories']!, Colors.orangeAccent),
                    _buildGoalBar('Prot', _totals['protein']!,  _goals['protein']!,  Colors.tealAccent),
                    _buildGoalBar('Carb', _totals['carbs']!,    _goals['carbs']!,    Colors.lightBlueAccent),
                    _buildGoalBar('Fat',  _totals['fat']!,      _goals['fat']!,      Colors.pinkAccent),
                  ],
                ),
              ),
            ),
          ],

          // ── Yesterday summary ──────────────────────────────
          if (_hasYesterday) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('YESTERDAY',
                      style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text(
                    '${_yesterday['calories']!.toStringAsFixed(0)} kcal'
                    '  •  P:${_yesterday['protein']!.toStringAsFixed(0)}g'
                    '  •  C:${_yesterday['carbs']!.toStringAsFixed(0)}g'
                    '  •  F:${_yesterday['fat']!.toStringAsFixed(0)}g',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white70, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          _buildFavoritesBar(),

          // ── Voice + text input card ────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Meal: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: _selectedMealType,
                      dropdownColor: const Color(0xFF1E1E1E),
                      items: _mealOrder
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedMealType = val!),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _isListening
                      ? "Listening: '$_spokenText'"
                      : 'Tap mic or type below.',
                  style: TextStyle(
                      color: _isListening ? Colors.tealAccent : Colors.grey,
                      fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: _addFood,
                      icon: const Icon(Icons.add, size: 18, color: Colors.tealAccent),
                      label: const Text('Add Food', style: TextStyle(color: Colors.tealAccent)),
                      ),
                    TextButton.icon(
                      onPressed: _copyYesterday,
                      icon: const Icon(Icons.copy_all, size: 18, color: Colors.tealAccent),
                      label: const Text('Copy Yesterday',
                          style: TextStyle(color: Colors.tealAccent)),
                      ),
                    ],
                ),
                const SizedBox(height: 12),
                _isLoading
                    ? const CircularProgressIndicator(color: Colors.tealAccent)
                    : GestureDetector(
                        onTap: _listen,
                        child: CircleAvatar(
                          radius: 35,
                          backgroundColor: _isListening
                              ? Colors.redAccent
                              : Colors.tealAccent,
                          child: Icon(
                              _isListening ? Icons.stop : Icons.mic,
                              color: Colors.black,
                              size: 30),
                        ),
                      ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        hintText: 'Or type your meal here...',
                        hintStyle: const TextStyle(fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF2A2A2A),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          _submitNetworkEntry(val.trim());
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.tealAccent),
                    onPressed: _isLoading
                        ? null
                        : () {
                            final text = _textController.text.trim();
                            if (text.isNotEmpty) _submitNetworkEntry(text);
                          },
                  ),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          const Align(
            alignment: Alignment.centerLeft,
            child: Text("TODAY'S LEDGER (SWIPE TO DELETE)",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
          ),
          const SizedBox(height: 8),

          // ── Grouped ledger ─────────────────────────────────
          Expanded(
            child: _todayMeals.isEmpty
                ? const Center(child: Text('No fuel components recorded.'))
                : ListView(
                    children: grouped.entries.map((entry) {
                      final mealType  = entry.key;
                      final meals     = entry.value;
                      final groupCals = meals.fold<double>(
                          0, (s, m) => s + (m['calories'] as num).toDouble());
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(mealType.toUpperCase(),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.tealAccent,
                                        letterSpacing: 1.2)),
                                Text('${groupCals.toStringAsFixed(0)} kcal',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                          ...meals.map((item) => Dismissible(
                                key: Key(item['log_id'].toString()),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  color: Colors.red.shade900,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  child: const Icon(Icons.delete,
                                      color: Colors.white),
                                ),
                                onDismissed: (_) =>
                                    _deleteEntry(item['log_id']),
                                child: Card(
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 3),
                                  child: ListTile(
                                    onTap: () => _editEntry(item),
                                    onLongPress: () => _favoriteEntry(item),
                                    title: Text(item['food_name_full'],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    subtitle: Text('${item['consumed_g']}g'),
                                    trailing: Text(
                                      '+${item['calories'].toStringAsFixed(0)} kcal\nP: ${item['protein'].toStringAsFixed(1)}g',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12),
                                    ),
                                  ),
                                ),
                              )),
                          const Divider(color: Color(0xFF2A2A2A)),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroCard(
      String label, String value, String unit, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
        child: Column(children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color)),
          Text(unit,
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ]),
      ),
    );
  }

  Widget _buildFavoritesBar() {
  if (_favorites.isEmpty) return const SizedBox.shrink();
  return Container(
    height: 40,
    margin: const EdgeInsets.only(bottom: 10),
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _favorites.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final fav = _favorites[i];
        return GestureDetector(
          onLongPress: () => _confirmDeleteFavorite(fav),
          child: ActionChip(
            avatar: const Icon(Icons.star, size: 16, color: Colors.amber),
            label: Text(fav['label'] as String),
            backgroundColor: const Color(0xFF1E1E1E),
            onPressed: () => _logFavorite(fav),
          ),
        );
      },
    ),
  );
}

  Widget _buildGoalBar(
      String label, double current, double goal, Color color) {
    if (goal <= 0) return const SizedBox.shrink();
    final progress = (current / goal).clamp(0.0, 1.0);
    final isOver   = current > goal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(
          width: 36,
          child: Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ),
        Expanded(
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: const Color(0xFF2A2A2A),
            valueColor: AlwaysStoppedAnimation<Color>(
                isOver ? Colors.redAccent : color),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${current.toStringAsFixed(0)}/${goal.toStringAsFixed(0)}',
          style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
              fontFamily: 'monospace'),
        ),
      ]),
    );
  }
}
class _ClarifyOption {
  final String title;
  final double kcalAtQty;
  final Map<String, dynamic> data;
  final bool showChevron;
  _ClarifyOption({
    required this.title,
    required this.kcalAtQty,
    required this.data,
    this.showChevron = false,
  });
}