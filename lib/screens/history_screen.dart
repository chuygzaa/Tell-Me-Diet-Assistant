import 'package:flutter/material.dart';
import '../diary_db.dart';
import '../widgets/app_states.dart';

class HistoryScreen extends StatefulWidget {
  final bool isActive;
  const HistoryScreen({super.key, required this.isActive});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _dates = [];
  String? _selectedDate;
  List<Map<String, dynamic>> _selectedDayMeals = [];
  bool _isLoading = true;

  static const List<String> _mealOrder = [
    'Breakfast', 'Brunch', 'Lunch', 'Dinner', 'Supper', 'Snack'
  ];

  @override
  void initState() {
    super.initState();
    _loadDates();
  }

  @override
  void didUpdateWidget(HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
  // Reload every time this tab becomes the active one
    if (widget.isActive && !oldWidget.isActive) {
      _loadDates();
  }
}
  Future<void> _loadDates() async {
    final dates = await DiaryDatabase.instance.getAllDates();
    setState(() {
      _dates = dates;
      _isLoading = false;
    });
  }

  Future<void> _selectDate(String dateYMD) async {
    final meals = await DiaryDatabase.instance.getMealsByDate(dateYMD);
    setState(() {
      _selectedDate     = dateYMD;
      _selectedDayMeals = meals;
    });
  }

  Future<void> _goBack() async {
    setState(() {
      _selectedDate     = null;
      _selectedDayMeals = [];
    });
    await _loadDates();
  }

  Future<void> _deleteEntry(int logId) async {
    await DiaryDatabase.instance.deleteMeal(logId);
    if (_selectedDate != null) await _selectDate(_selectedDate!);
    await _loadDates();
  }

  Map<String, List<Map<String, dynamic>>> _groupByMealType(
      List<Map<String, dynamic>> meals) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final meal in meals) {
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

  // ── LEVEL 2: Day detail ──────────────────────────────────────
  Widget _buildDayDetail() {
    final grouped   = _groupByMealType(_selectedDayMeals);
    final totalCals = _selectedDayMeals.fold<double>(
        0, (s, m) => s + (m['calories'] as num).toDouble());
    final totalProt = _selectedDayMeals.fold<double>(
        0, (s, m) => s + (m['protein'] as num).toDouble());

    return Column(children: [
      // Back header
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.tealAccent),
            onPressed: _goBack,
          ),
          Text(_selectedDate!,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Spacer(),
          Text(
            '${totalCals.toStringAsFixed(0)} kcal  •  P:${totalProt.toStringAsFixed(0)}g',
            style: const TextStyle(
                color: Colors.grey, fontSize: 12, fontFamily: 'monospace'),
          ),
        ]),
      ),
      const Divider(color: Color(0xFF2A2A2A), height: 1),
      Expanded(
        child: _selectedDayMeals.isEmpty
            ? const Center(child: Text('No entries for this day.'))
            : ListView(
                padding: const EdgeInsets.all(12),
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
                            key: Key('hist_${item['log_id']}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Colors.red.shade900,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) => _deleteEntry(item['log_id']),
                            child: Card(
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              child: ListTile(
                                title: Text(item['food_name_full'],
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text('${item['consumed_g']}g'),
                                trailing: Text(
                                  '+${item['calories'].toStringAsFixed(0)} kcal\nP: ${item['protein'].toStringAsFixed(1)}g',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      fontFamily: 'monospace', fontSize: 12),
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
    ]);
  }

  // ── LEVEL 1: Date list ───────────────────────────────────────
  Widget _buildDateList() {
    if (_dates.isEmpty) {
      return const EmptyState(
        icon: Icons.history,
        title: 'No history yet',
        message: 'Once you log meals, each day will appear here. Tap a day to see the full breakdown.',
  );
}
    return RefreshIndicator (
      onRefresh: _loadDates,
      color: Colors.tealAccent,
      child: ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _dates.length,
      itemBuilder: (context, index) {
        final entry = _dates[index];
        final date  = entry['date'] as String;
        final cals  = (entry['total_cals']    as num?)?.toStringAsFixed(0) ?? '0';
        final prot  = (entry['total_protein'] as num?)?.toStringAsFixed(0) ?? '0';
        final carbs = (entry['total_carbs']   as num?)?.toStringAsFixed(0) ?? '0';
        final fat   = (entry['total_fat']     as num?)?.toStringAsFixed(0) ?? '0';
        final count = entry['item_count'] as int? ?? 0;


        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            onTap: () => _selectDate(date),
            leading: const Icon(Icons.calendar_today,
                color: Colors.tealAccent, size: 20),
            title: Text(date,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('$count items logged',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$cals kcal',
                    style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontFamily: 'monospace',
                        fontSize: 13)),
                Text('P:${prot}g  C:${carbs}g  F:${fat}g',
                    style: const TextStyle(
                        color: Colors.grey,
                        fontFamily: 'monospace',
                        fontSize: 10)),
              ],
            ),
          ),
        );
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SkeletonList();
    }
    return _selectedDate != null ? _buildDayDetail() : _buildDateList();
  }
}