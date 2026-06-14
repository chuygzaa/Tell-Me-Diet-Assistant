import 'package:flutter/material.dart';
import '../services/profile_service.dart';
import '../services/goals_service.dart';
import '../diary_db.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  final _name = TextEditingController();
  String _sex = 'Male';

  final _weight  = TextEditingController();
  final _cal     = TextEditingController();
  final _protPct = TextEditingController();
  final _carbPct = TextEditingController();
  final _fatPct  = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Sensible default split (sums to 100%)
    _protPct.text = '30';
    _carbPct.text = '40';
    _fatPct.text  = '30';
  }

  @override
  void dispose() {
    _pageController.dispose();
    _name.dispose();
    _weight.dispose();
    _cal.dispose();
    _protPct.dispose();
    _carbPct.dispose();
    _fatPct.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == 0 && _name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter your name to continue.')));
      return;
    }
    if (_page < 2) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_page > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  double get _calVal => double.tryParse(_cal.text) ?? 0;

  double _macroGrams(TextEditingController pctCtrl, double kcalPerGram) {
    final pct = double.tryParse(pctCtrl.text) ?? 0;
    return (_calVal * pct / 100) / kcalPerGram;
  }

  double get _totalPct =>
      (double.tryParse(_protPct.text) ?? 0) +
      (double.tryParse(_carbPct.text) ?? 0) +
      (double.tryParse(_fatPct.text) ?? 0);

  Future<void> _finish() async {
    await ProfileService.saveProfile(name: _name.text.trim(), sex: _sex);

    // Seed today's weight so weight tracking / TDEE start from day one
    final weight = double.tryParse(_weight.text) ?? 0;
    if (weight > 0) {
      final now = DateTime.now();
      final ymd =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      await DiaryDatabase.instance.upsertWeight(ymd, weight);
    }

    // Macros derived from calorie goal × % → always internally consistent
    final cal   = _calVal;
    final protG = (cal * (double.tryParse(_protPct.text) ?? 0) / 100) / 4;
    final carbG = (cal * (double.tryParse(_carbPct.text) ?? 0) / 100) / 4;
    final fatG  = (cal * (double.tryParse(_fatPct.text) ?? 0) / 100) / 9;

    await GoalsService.saveGoals(
      calories: cal, protein: protG, carbs: carbG, fat: fatG,
    );
    await ProfileService.setOnboardingComplete();
    widget.onDone();
  }

  Widget _field(String label, TextEditingController c,
      {TextInputType? kt, String? suffix, VoidCallback? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: kt,
        onChanged: onChanged == null ? null : (_) => onChanged(),
        decoration: InputDecoration(
          labelText: label, suffixText: suffix,
          filled: true, fillColor: const Color(0xFF2A2A2A),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _proteinNote() {
    final w = double.tryParse(_weight.text) ?? 0;
    final extra = w > 0 ? ' (≈ ${w.toStringAsFixed(0)} g for you)' : '';
    return Text(
      'Tip: protein goal should be ~1 g per lb of bodyweight$extra.',
      style: const TextStyle(
          color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
    );
  }

  Widget _macroPctRow(String label, TextEditingController pctCtrl,
      double kcalPerGram, Color color) {
    final grams = _macroGrams(pctCtrl, kcalPerGram);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: pctCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(color: color),
                suffixText: '%',
                filled: true, fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text('${grams.toStringAsFixed(0)} g',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _goalSummary() {
    final total = _totalPct;
    final macroKcal = _calVal * total / 100;
    final ok = (total - 100).abs() < 0.5;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Split total: ${total.toStringAsFixed(0)}%',
              style: TextStyle(
                  color: ok ? Colors.tealAccent : Colors.orangeAccent,
                  fontWeight: FontWeight.bold)),
          Text('${macroKcal.toStringAsFixed(0)} / ${_calVal.toStringAsFixed(0)} kcal',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _welcomePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.bolt, color: Colors.tealAccent, size: 48),
          const SizedBox(height: 16),
          const Text('Welcome',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Let\u2019s set up your profile. This personalizes your nutrient '
            'targets and dashboard.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          _field('Your name', _name),
          const SizedBox(height: 8),
          const Text('Sex (used for nutrient RDA targets)',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['Male', 'Female'].map((s) {
              final selected = _sex == s;
              return ChoiceChip(
                label: Text(s),
                selected: selected,
                selectedColor: Colors.tealAccent,
                labelStyle:
                    TextStyle(color: selected ? Colors.black : Colors.white),
                backgroundColor: const Color(0xFF2A2A2A),
                onSelected: (_) => setState(() => _sex = s),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _goalsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text('Daily goals',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Enter your calorie goal and macro split as percentages of calories — '
            'grams are calculated for you so everything ties out. '
            'Leave calories blank to skip.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          _field('Current weight', _weight,
              kt: TextInputType.number, suffix: 'lb',
              onChanged: () => setState(() {})),
          _proteinNote(),
          const SizedBox(height: 16),
          _field('Calorie goal', _cal,
              kt: TextInputType.number, suffix: 'kcal',
              onChanged: () => setState(() {})),
          const SizedBox(height: 8),
          const Text('Macro split (% of calories → grams)',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          _macroPctRow('Protein', _protPct, 4, Colors.tealAccent),
          _macroPctRow('Carbs', _carbPct, 4, Colors.lightBlueAccent),
          _macroPctRow('Fat', _fatPct, 9, Colors.pinkAccent),
          const SizedBox(height: 4),
          _goalSummary(),
        ],
      ),
    );
  }

  Widget _tourPage() {
    Widget tile(IconData icon, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.tealAccent, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(body,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text('How it works',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          tile(Icons.mic, 'Meal Logger',
              'Speak or type what you ate \u2014 it\u2019s parsed and logged automatically.'),
          tile(Icons.history, 'History',
              'Drill into any past day, meal by meal.'),
          tile(Icons.dashboard, 'Dashboard',
              'Macro averages, micronutrients, and your TDEE estimate.'),
          tile(Icons.monitor_weight_outlined, 'Weight',
              'Log weight to power the TDEE regression and trends.'),
          tile(Icons.settings, 'Settings',
              'Adjust goals and preferences any time.'),
          const SizedBox(height: 8),
          const Text('You\u2019re all set.',
              style: TextStyle(color: Colors.tealAccent)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [_welcomePage(), _goalsPage(), _tourPage()],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: _page > 0
                        ? TextButton(onPressed: _back, child: const Text('Back'))
                        : null,
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == _page
                                  ? Colors.tealAccent
                                  : Colors.grey.shade700,
                            ),
                          )),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent,
                          foregroundColor: Colors.black),
                      child: Text(_page == 2 ? 'Finish' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}