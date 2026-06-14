import 'dart:math';
import 'package:flutter/material.dart';
import '../services/goals_service.dart';
import '../diary_db.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

bool _clarifyEnabled = true;

class _SettingsScreenState extends State<SettingsScreen> {
  final _calCtrl  = TextEditingController();
  final _protCtrl = TextEditingController();
  final _carbCtrl = TextEditingController();
  final _fatCtrl  = TextEditingController();
  bool _isSaving   = false;
  bool _isLoaded   = false;
  bool _isDummy    = false;  // dummy data in progress

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  @override
  void dispose() {
    _calCtrl.dispose(); _protCtrl.dispose();
    _carbCtrl.dispose(); _fatCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
  final goals = await GoalsService.getGoals();
  final clarify = await SettingsService.getClarifyEnabled();
  setState(() {
    _calCtrl.text  = goals['calories']! > 0 ? goals['calories']!.toStringAsFixed(0) : '';
    _protCtrl.text = goals['protein']!  > 0 ? goals['protein']!.toStringAsFixed(0)  : '';
    _carbCtrl.text = goals['carbs']!    > 0 ? goals['carbs']!.toStringAsFixed(0)    : '';
    _fatCtrl.text  = goals['fat']!      > 0 ? goals['fat']!.toStringAsFixed(0)      : '';
    _clarifyEnabled = clarify;
    _isLoaded = true;
  });
}

  Future<void> _saveGoals() async {
    setState(() => _isSaving = true);
    await GoalsService.saveGoals(
      calories: double.tryParse(_calCtrl.text)  ?? 0.0,
      protein:  double.tryParse(_protCtrl.text) ?? 0.0,
      carbs:    double.tryParse(_carbCtrl.text) ?? 0.0,
      fat:      double.tryParse(_fatCtrl.text)  ?? 0.0,
    );
    setState(() => _isSaving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Goals saved.'),
            backgroundColor: Colors.teal));
    }
  }

  // ── Dummy data ────────────────────────────────────────────────

  double _gaussian(Random rand, double mean, double std) {
    final u1 = rand.nextDouble();
    final u2 = rand.nextDouble();
    final z  = sqrt(-2.0 * log(u1 + 1e-10)) * cos(2.0 * pi * u2);
    return mean + z * std;
  }

  double _clamp(double v, double lo, double hi) =>
      v < lo ? lo : (v > hi ? hi : v);

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  Future<void> _insertDummyData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Insert Dummy Data'),
        content: const Text(
            '60 days of synthetic food and weight entries will be added '
            'for TDEE regression testing. Existing data is untouched.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Insert', style: TextStyle(color: Colors.tealAccent))),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDummy = true);
    final rand  = Random(42);
    final db    = await DiaryDatabase.instance.database;
    final start = DateTime.now().subtract(const Duration(days: 60));

    for (int day = 0; day < 60; day++) {
      final date    = start.add(Duration(days: day));
      final dateStr = _fmtDate(date);

      // Calories N(2500,200) capped [1750,3250]
      final calories = _clamp(_gaussian(rand, 2500, 200), 1750, 3250);

      // Protein N(185,10) capped [160,225]
      final protein  = _clamp(_gaussian(rand, 185, 10), 160, 225);
      final protCals = protein * 4;
      final remaining = calories - protCals;

      // Fat/carb even split with slight daily variance
      final fatFrac  = _clamp(_gaussian(rand, 0.5, 0.05), 0.35, 0.65);
      final fat      = _clamp((remaining * fatFrac) / 9, 30, 180);
      final carbs    = _clamp((remaining * (1 - fatFrac)) / 4, 30, 500);

      await db.insert('diary_log', {
        'timestamp':      '${dateStr}T12:00:00.000000',
        'meal_type':      'Lunch',
        'food_id':        0,
        'user_food_name': 'dummy',
        'food_name_full': 'Dummy Data — Daily Summary',
        'consumed_g':     0.0,
        'calories':       double.parse(calories.toStringAsFixed(1)),
        'protein':        double.parse(protein.toStringAsFixed(1)),
        'carbs':          double.parse(carbs.toStringAsFixed(1)),
        'fat':            double.parse(fat.toStringAsFixed(1)),
        'sugar_g': 0.0, 'fiber_g': 0.0, 'vita_mcg': 0.0, 'vitb6_mg': 0.0,
        'vitb12_mcg': 0.0, 'vitc_mg': 0.0, 'vite_mg': 0.0, 'folate_mcg': 0.0,
        'niacin_mg': 0.0, 'riboflavin_mg': 0.0, 'thiamin_mg': 0.0,
        'calcium_mg': 0.0, 'copper_mcg': 0.0, 'iron_mg': 0.0,
        'magnesium_mg': 0.0, 'manganese_mg': 0.0, 'phosphorus_mg': 0.0,
        'selenium_mcg': 0.0, 'zinc_mg': 0.0,
      });

      // Weight: 170 → 165 at day 30 → 162 at day 60 + noise
      final trend  = day <= 30
          ? 170.0 - (day / 30.0) * 5.0
          : 165.0 - ((day - 30) / 30.0) * 3.0;
      final weight = _clamp(trend + _gaussian(rand, 0, 0.5), 158.0, 175.0);
      await DiaryDatabase.instance.upsertWeight(
          dateStr, double.parse(weight.toStringAsFixed(1)));
    }

    setState(() => _isDummy = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 60 days of dummy data inserted.'),
            backgroundColor: Colors.teal));
    }
  }

  Future<void> _clearDummyData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Clear Dummy Data'),
        content: const Text(
            'Removes all "Dummy Data" diary entries and the weight entries '
            'logged on those same dates. Real data on other dates is untouched.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDummy = true);
    final db = await DiaryDatabase.instance.database;

    // Get dummy entry dates first
    final rows = await db.rawQuery(
        "SELECT DISTINCT substr(timestamp,1,10) as d FROM diary_log "
        "WHERE food_name_full = ?",
        ['Dummy Data — Daily Summary']);

    // Delete diary entries
    await db.delete('diary_log',
        where: 'food_name_full = ?',
        whereArgs: ['Dummy Data — Daily Summary']);

    // Delete weight entries only on those exact dates
    for (final row in rows) {
      await db.delete('weight_log',
          where: 'date = ?', whereArgs: [row['d']]);
    }

    setState(() => _isDummy = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🗑 Dummy data cleared.'),
            backgroundColor: Colors.redAccent));
    }
  }

  // ── Shared widget ─────────────────────────────────────────────
  Widget _goalField(String label, TextEditingController ctrl,
      String unit, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label, labelStyle: TextStyle(color: color),
          suffixText: unit,
          filled: true, fillColor: const Color(0xFF1E1E1E),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: color)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.tealAccent));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Daily goals ───────────────────────────────────────
          const Text('DAILY GOALS',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                  color: Colors.grey, letterSpacing: 1.2)),
          const SizedBox(height: 4),
          const Text('Set your targets. Progress bars on the logger update automatically.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 20),
          _goalField('Calorie Goal', _calCtrl,  'kcal', Colors.orangeAccent),
          _goalField('Protein Goal', _protCtrl, 'g',    Colors.tealAccent),
          _goalField('Carb Goal',    _carbCtrl, 'g',    Colors.lightBlueAccent),
          _goalField('Fat Goal',     _fatCtrl,  'g',    Colors.pinkAccent),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveGoals,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text('SAVE GOALS',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 32),

          const Divider(color: Color(0xFF2A2A2A)),
const SizedBox(height: 16),
const Text('LOGGING',
    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
        color: Colors.grey, letterSpacing: 1.2)),
SwitchListTile(
  contentPadding: EdgeInsets.zero,
  activeColor: Colors.tealAccent,
  title: const Text('Ask when uncertain'),
  subtitle: const Text(
      'When a spoken food could match very different cuts (e.g. steak), '
      'ask before logging.',
      style: TextStyle(fontSize: 12, color: Colors.grey)),
  value: _clarifyEnabled,
  onChanged: (v) async {
    setState(() => _clarifyEnabled = v);
    await SettingsService.setClarifyEnabled(v);
  },
),
const SizedBox(height: 16),

          // ── Debug / TDEE dummy data ───────────────────────────
          const Divider(color: Color(0xFF2A2A2A)),
          const SizedBox(height: 16),
          const Text('DEBUG — TDEE REGRESSION TESTING',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                  color: Colors.grey, letterSpacing: 1.2)),
          const SizedBox(height: 4),
          const Text(
              '60 days of synthetic calorie + weight data. '
              'Used to test the TDEE regression before real data accumulates. '
              'Clear when done.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
          _isDummy
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.tealAccent))
              : Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _insertDummyData,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E1E1E),
                          foregroundColor: Colors.tealAccent,
                          side: const BorderSide(color: Colors.tealAccent)),
                      icon: const Icon(Icons.science_outlined, size: 18),
                      label: const Text('Insert Dummy Data'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _clearDummyData,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E1E1E),
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent)),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Clear Dummy Data'),
                    ),
                  ),
                ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}