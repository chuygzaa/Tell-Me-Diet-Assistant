import 'package:flutter/material.dart';
import '../diary_db.dart';

class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key});

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  final TextEditingController _weightController = TextEditingController();
  List<Map<String, dynamic>> _history = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  String _getTodayYMD() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadHistory() async {
    final data = await DiaryDatabase.instance.getWeightHistory();
    setState(() => _history = data.reversed.toList()); // most recent first
  }

  Future<void> _logWeight() async {
    final input = _weightController.text.trim();
    if (input.isEmpty) return;
    final weight = double.tryParse(input);
    if (weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid weight.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    await DiaryDatabase.instance.upsertWeight(_getTodayYMD(), weight);
    _weightController.clear();
    await _loadHistory();
    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ ${weight.toStringAsFixed(1)} lbs logged for today.'),
        backgroundColor: Colors.teal.shade700,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = _history.isNotEmpty ? _history.first : null;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Latest weight
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('CURRENT WEIGHT',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(
                    latest != null
                        ? '${(latest['weight_lbs'] as num).toStringAsFixed(1)} lbs'
                        : '— lbs',
                    style: const TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 28,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Input row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'Enter weight (lbs)',
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    suffixText: 'lbs',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _isSaving
                  ? const CircularProgressIndicator(color: Colors.tealAccent)
                  : ElevatedButton(
                      onPressed: _logWeight,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 18),
                      ),
                      child: const Text('LOG',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
            ],
          ),
          const SizedBox(height: 20),

          const Text('WEIGHT HISTORY',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          const SizedBox(height: 8),

          // History list
          Expanded(
            child: _history.isEmpty
                ? const Center(child: Text('No weight entries yet.'))
                : ListView.builder(
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final entry = _history[index];
                      final isToday = entry['date'] == _getTodayYMD();
                      return ListTile(
                        dense: true,
                        title: Text(entry['date'],
                            style: TextStyle(
                                color: isToday
                                    ? Colors.tealAccent
                                    : Colors.white)),
                        trailing: Text(
                          '${(entry['weight_lbs'] as num).toStringAsFixed(1)} lbs',
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 14),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}