import 'package:flutter/material.dart';
import '../diary_db.dart';
import 'tdee_tab.dart';
import '../widgets/app_states.dart';
import '../services/profile_service.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsScreen extends StatefulWidget {
  final bool isActive;
  const AnalyticsScreen({super.key, required this.isActive});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  double _avgCals = 0, _avgProtein = 0, _avgCarbs = 0, _avgFat = 0;
  double _pctProtein = 0, _pctCarbs = 0, _pctFat = 0;
  double? _avgWeight, _latestWeight, _earliestWeight;
  List<Map<String, dynamic>> _weightEntries = [];
  int _daysTracked = 0;
  List<bool> _last7DaysMask = [];
  Map<String, double> _microAvgs = {};
  String _sex = 'Male';
  Map<String, double> get _activeRda => _sex == 'Female' ? _rdaFemale : _rda;

  static const Map<String, double> _rda = {
    'fiber_g': 38,    'sugar_g': 50,
    'vita_mcg': 900,  'vitb6_mg': 1.7,  'vitb12_mcg': 2.4,
    'vitc_mg': 90,    'vite_mg': 15,    'folate_mcg': 400,
    'niacin_mg': 16,  'riboflavin_mg': 1.3, 'thiamin_mg': 1.2,
    'calcium_mg': 1000,'copper_mcg': 900, 'iron_mg': 8,
    'magnesium_mg': 420,'manganese_mg': 2.3,'phosphorus_mg': 700,
    'selenium_mcg': 55,'zinc_mg': 11,
  };
  static const Map<String, double> _rdaFemale = {
    'fiber_g': 25,      'sugar_g': 50,
    'vita_mcg': 700,    'vitb6_mg': 1.7,      'vitb12_mcg': 2.4,
    'vitc_mg': 75,      'vite_mg': 15,        'folate_mcg': 400,
    'niacin_mg': 14,    'riboflavin_mg': 1.1, 'thiamin_mg': 1.1,
    'calcium_mg': 1000, 'copper_mcg': 900,    'iron_mg': 18,
    'magnesium_mg': 320,'manganese_mg': 1.8,  'phosphorus_mg': 700,
    'selenium_mcg': 55, 'zinc_mg': 8,
  };
  static const Map<String, String> _labels = {
    'fiber_g':'Fiber','sugar_g':'Sugar','vita_mcg':'Vitamin A',
    'vitb6_mg':'Vitamin B6','vitb12_mcg':'Vitamin B12','vitc_mg':'Vitamin C',
    'vite_mg':'Vitamin E','folate_mcg':'Folate','niacin_mg':'Niacin',
    'riboflavin_mg':'Riboflavin','thiamin_mg':'Thiamin','calcium_mg':'Calcium',
    'copper_mcg':'Copper','iron_mg':'Iron','magnesium_mg':'Magnesium',
    'manganese_mg':'Manganese','phosphorus_mg':'Phosphorus',
    'selenium_mcg':'Selenium','zinc_mg':'Zinc',
  };
  static const Map<String, String> _units = {
    'fiber_g':'g','sugar_g':'g','vita_mcg':'mcg','vitb6_mg':'mg',
    'vitb12_mcg':'mcg','vitc_mg':'mg','vite_mg':'mg','folate_mcg':'mcg',
    'niacin_mg':'mg','riboflavin_mg':'mg','thiamin_mg':'mg','calcium_mg':'mg',
    'copper_mcg':'mcg','iron_mg':'mg','magnesium_mg':'mg','manganese_mg':'mg',
    'phosphorus_mg':'mg','selenium_mcg':'mcg','zinc_mg':'mg',
  };
  static const List<String> _macroNutrients = ['fiber_g','sugar_g'];
  static const List<String> _vitamins = [
    'vita_mcg','vitb6_mg','vitb12_mcg','vitc_mg','vite_mg',
    'folate_mcg','niacin_mg','riboflavin_mg','thiamin_mg',
  ];
  static const List<String> _minerals = [
    'calcium_mg','copper_mcg','iron_mg','magnesium_mg','manganese_mg',
    'phosphorus_mg','selenium_mcg','zinc_mg',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAnalytics();
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  @override
  void didUpdateWidget(AnalyticsScreen old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) _loadAnalytics();
  }

  String _dateYMD(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    final allDates   = await DiaryDatabase.instance.getAllDates();
    final weightHist = await DiaryDatabase.instance.getWeightHistory();
    final microAvgs  = await DiaryDatabase.instance.getLast7DaysMicronutrientAverages();
    final sex = await ProfileService.getSex();
    _sex = sex == 'Female' ? 'Female' : 'Male';

    final recent7 = allDates.take(7).toList();
    if (recent7.isNotEmpty) {
      final n = recent7.length.toDouble();
      _avgCals    = recent7.fold<double>(0,(s,d)=>s+(d['total_cals']    as num? ??0).toDouble())/n;
      _avgProtein = recent7.fold<double>(0,(s,d)=>s+(d['total_protein'] as num? ??0).toDouble())/n;
      _avgCarbs   = recent7.fold<double>(0,(s,d)=>s+(d['total_carbs']   as num? ??0).toDouble())/n;
      _avgFat     = recent7.fold<double>(0,(s,d)=>s+(d['total_fat']     as num? ??0).toDouble())/n;
      final t = (_avgProtein*4)+(_avgCarbs*4)+(_avgFat*9);
      if (t > 0) {
        _pctProtein = (_avgProtein*4)/t;
        _pctCarbs   = (_avgCarbs*4)/t;
        _pctFat     = (_avgFat*9)/t;
      }
    }

    final loggedDates = allDates.map((d)=>d['date'] as String).toSet();
    _last7DaysMask = List.generate(7,(i){
      return loggedDates.contains(_dateYMD(DateTime.now().subtract(Duration(days:6-i))));
    });
    _daysTracked = _last7DaysMask.where((b)=>b).length;

    _weightEntries = weightHist.reversed.take(7).toList().reversed.toList();
    if (_weightEntries.isNotEmpty) {
      _latestWeight   = (_weightEntries.last['weight_lbs']  as num).toDouble();
      _earliestWeight = (_weightEntries.first['weight_lbs'] as num).toDouble();
      _avgWeight = _weightEntries.fold<double>(
          0,(s,e)=>s+(e['weight_lbs'] as num).toDouble()) / _weightEntries.length;
    }
    _microAvgs = microAvgs;
    setState(() => _isLoading = false);
  }

  Color _rdaColor(double pct) {
    if (pct >= 1.0)  return Colors.tealAccent;
    if (pct >= 0.75) return Colors.lightBlueAccent;
    if (pct >= 0.50) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SkeletonList();
    }
    return Column(children: [
      TabBar(
        controller: _tabController,
        indicatorColor: Colors.tealAccent,
        labelColor: Colors.tealAccent,
        unselectedLabelColor: Colors.grey,
        tabs: const [
          Tab(text: 'SUMMARY'),
          Tab(text: 'MICRONUTRIENTS'),
          Tab(text: 'TDEE'),
        ],
      ),
      Expanded(child: TabBarView(
        controller: _tabController,
        children: [
          _buildSummaryTab(),
          _buildMicroTab(),
          const TDEETab(),
        ],
      )),
    ]);
  }

  // ── Tab 1: Summary ───────────────────────────────────────────────────────
  Widget _buildSummaryTab() => RefreshIndicator(
    onRefresh: _loadAnalytics,
    color: Colors.tealAccent,
    child: ListView(padding: const EdgeInsets.all(16), children: [
      _sec('7-DAY AVERAGES'), const SizedBox(height:8),
      Row(children: [
        Expanded(child: _statCard('Calories', '${_avgCals.toStringAsFixed(0)} kcal',    Colors.orangeAccent)),
        Expanded(child: _statCard('Protein',  '${_avgProtein.toStringAsFixed(1)} g',    Colors.tealAccent)),
        Expanded(child: _statCard('Carbs',    '${_avgCarbs.toStringAsFixed(1)} g',      Colors.lightBlueAccent)),
        Expanded(child: _statCard('Fat',      '${_avgFat.toStringAsFixed(1)} g',        Colors.pinkAccent)),
      ]),
      const SizedBox(height:16),
      _sec('MACRO DISTRIBUTION (7-day avg)'), const SizedBox(height:8),
      Card(child: Padding(padding: const EdgeInsets.all(14), child: _macroDonut())),
      const SizedBox(height:16),
      _sec('TRACKING CONSISTENCY — LAST 7 DAYS'), const SizedBox(height:8),
      Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7,(i){
                final day = DateTime.now().subtract(Duration(days:6-i));
                final ok  = _last7DaysMask[i];
                return Column(children: [
                  Container(width:32,height:32,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: ok ? Colors.tealAccent.withOpacity(0.85)
                            : const Color(0xFF2A2A2A)),
                    child: Center(child: Icon(ok?Icons.check:Icons.remove,
                        size:16, color: ok?Colors.black:Colors.grey)),
                  ),
                  const SizedBox(height:4),
                  Text(['M','T','W','T','F','S','S'][day.weekday%7],
                      style: const TextStyle(fontSize:10, color:Colors.grey)),
                ]);
              })),
          const SizedBox(height:10),
          Text('$_daysTracked of 7 days logged',
              style: TextStyle(color: _daysTracked>=5
                  ? Colors.tealAccent : _daysTracked>=3
                  ? Colors.orangeAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold)),
        ],
      ))),
      const SizedBox(height:16),
      _sec('WEIGHT TREND'), const SizedBox(height:8),
      _weightEntries.isEmpty
          ? Card(child: Padding(padding: const EdgeInsets.all(14),
              child: const Text('No weight data yet.',
                  style: TextStyle(color: Colors.grey))))
          : Card(child: Padding(padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    _wtStat('Current',  '${_latestWeight!.toStringAsFixed(1)} lbs', Colors.tealAccent),
                    _wtStat('7-Day Avg','${_avgWeight!.toStringAsFixed(1)} lbs',    Colors.white70),
                    _wtStat('Trend',
                      _latestWeight! < _earliestWeight!
                          ? '↓ ${(_earliestWeight!-_latestWeight!).toStringAsFixed(1)} lbs'
                          : _latestWeight! > _earliestWeight!
                          ? '↑ ${(_latestWeight!-_earliestWeight!).toStringAsFixed(1)} lbs'
                          : '→ Stable',
                      _latestWeight! < _earliestWeight! ? Colors.tealAccent
                          : _latestWeight! > _earliestWeight! ? Colors.redAccent
                          : Colors.grey),
                  ]),
                  const SizedBox(height:12),
                  const Divider(color: Color(0xFF2A2A2A)),
                  const SizedBox(height:12),
                  _weightLineChart(),
                ]))),
      const SizedBox(height:24),
    ]),
  );

  // ── Tab 2: Micronutrients ────────────────────────────────────────────────
  Widget _buildMicroTab() {
    if (_microAvgs.isEmpty) {
      return const EmptyState(
        icon: Icons.science_outlined,
        title: 'No nutrient data yet',
        message: 'Log a few meals and your 7-day micronutrient averages will show up here.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      color: Colors.tealAccent,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Text('7-day daily averages vs RDA (adult ${_sex.toLowerCase()}). Pull to refresh.',
          style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height:16),
        _microSection('FIBER & SUGAR', _macroNutrients),
        const SizedBox(height:16),
        _microSection('VITAMINS', _vitamins),
        const SizedBox(height:16),
        _microSection('MINERALS', _minerals),
        const SizedBox(height:24),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _dot(Colors.tealAccent,      '≥ 100%'),
          const SizedBox(width:12),
          _dot(Colors.lightBlueAccent, '75–99%'),
          const SizedBox(width:12),
          _dot(Colors.orangeAccent,    '50–74%'),
          const SizedBox(width:12),
          _dot(Colors.redAccent,       '< 50%'),
        ]),
        const SizedBox(height:24),
      ]),
    );
  }

  Widget _microSection(String title, List<String> keys) => Card(
    child: Padding(padding: const EdgeInsets.all(14), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize:11,fontWeight:FontWeight.bold,
            color:Colors.grey,letterSpacing:1.1)),
        const SizedBox(height:10),
        ...keys.map((key) {
          final rda    = _activeRda[key] ?? 1;
          final avg    = _microAvgs[key] ?? 0;
          final pct    = (avg/rda).clamp(0.0,1.0);
          final color  = _rdaColor(avg/rda);
          final label  = _labels[key] ?? key;
          final unit   = _units[key] ?? '';
          return Padding(padding: const EdgeInsets.symmetric(vertical:5),
            child: Row(children: [
              SizedBox(width:90,
                  child: Text(label,
                      style: const TextStyle(fontSize:12,color:Colors.white70))),
              Expanded(child: LinearProgressIndicator(
                value: pct, minHeight:7,
                backgroundColor: const Color(0xFF2A2A2A),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              )),
              const SizedBox(width:8),
              SizedBox(width:80,
                  child: Text(
                    '${avg.toStringAsFixed(avg<10?1:0)}$unit'
                    ' (${(avg/rda*100).toStringAsFixed(0)}%)',
                    style: TextStyle(fontSize:10,color:color,
                        fontFamily:'monospace'),
                    textAlign: TextAlign.right,
                  )),
            ]),
          );
        }),
      ],
    )),
  );

  // ── Shared widgets ───────────────────────────────────────────────────────
  Widget _sec(String t) => Text(t,
      style: const TextStyle(fontSize:11,fontWeight:FontWeight.bold,
          color:Colors.grey,letterSpacing:1.2));

  Widget _statCard(String l, String v, Color c) => Card(
    child: Padding(padding: const EdgeInsets.symmetric(vertical:14,horizontal:4),
      child: Column(children: [
        Text(l, style: const TextStyle(fontSize:11,color:Colors.grey)),
        const SizedBox(height:6),
        Text(v, style: TextStyle(fontSize:14,fontWeight:FontWeight.bold,color:c),
            textAlign: TextAlign.center),
      ])),
  );

  Widget _macroBar(String l, double pct, Color c) => Row(children: [
    SizedBox(width:56, child: Text(l,
        style: const TextStyle(fontSize:12,color:Colors.grey))),
    Expanded(child: LinearProgressIndicator(
      value:pct, minHeight:8,
      backgroundColor: const Color(0xFF2A2A2A),
      valueColor: AlwaysStoppedAnimation<Color>(c),
    )),
    const SizedBox(width:8),
    SizedBox(width:36, child: Text('${(pct*100).toStringAsFixed(0)}%',
        style: const TextStyle(fontSize:11,color:Colors.grey,
            fontFamily:'monospace'), textAlign: TextAlign.right)),
  ]);

  Widget _wtStat(String l, String v, Color c) => Column(children: [
    Text(l, style: const TextStyle(fontSize:11,color:Colors.grey)),
    const SizedBox(height:4),
    Text(v, style: TextStyle(fontSize:13,fontWeight:FontWeight.bold,color:c)),
  ]);

  Widget _macroDonut() {
    final p = _pctProtein, c = _pctCarbs, f = _pctFat;
    if (p + c + f <= 0) {
      return const Text('No macro data yet.', style: TextStyle(color: Colors.grey));
    }
    return SizedBox(
      height: 170,
      child: Row(children: [
        Expanded(
          flex: 3,
          child: PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 38,
            startDegreeOffset: -90,
            sections: [
              PieChartSectionData(
                value: p * 100, title: '${(p * 100).toStringAsFixed(0)}%',
                color: Colors.tealAccent, radius: 42,
                titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
              PieChartSectionData(
                value: c * 100, title: '${(c * 100).toStringAsFixed(0)}%',
                color: Colors.lightBlueAccent, radius: 42,
                titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
              PieChartSectionData(
                value: f * 100, title: '${(f * 100).toStringAsFixed(0)}%',
                color: Colors.pinkAccent, radius: 42,
                titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
            ],
          )),
        ),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _legendRow(Colors.tealAccent, 'Protein', _avgProtein),
              const SizedBox(height: 8),
              _legendRow(Colors.lightBlueAccent, 'Carbs', _avgCarbs),
              const SizedBox(height: 8),
              _legendRow(Colors.pinkAccent, 'Fat', _avgFat),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _legendRow(Color c, String label, double grams) => Row(children: [
    Container(width: 10, height: 10,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
    const SizedBox(width: 6),
    Text('$label  ${grams.toStringAsFixed(0)}g',
        style: const TextStyle(fontSize: 12, color: Colors.white70)),
  ]);

  Widget _weightLineChart() {
    if (_weightEntries.length < 2) {
      return const Text('Log at least two weigh-ins to see a trend chart.',
          style: TextStyle(color: Colors.grey));
    }
    final spots = <FlSpot>[];
    for (var i = 0; i < _weightEntries.length; i++) {
      spots.add(FlSpot(i.toDouble(),
          (_weightEntries[i]['weight_lbs'] as num).toDouble()));
    }
    final ys = spots.map((s) => s.y).toList();
    final minW = ys.reduce((a, b) => a < b ? a : b);
    final maxW = ys.reduce((a, b) => a > b ? a : b);
    final pad = ((maxW - minW) * 0.2).clamp(1.0, 50.0);
    final minY = minW - pad, maxY = maxW + pad;

    return SizedBox(
      height: 200,
      child: LineChart(LineChartData(
        minX: 0, maxX: (_weightEntries.length - 1).toDouble(),
        minY: minY, maxY: maxY,
        lineTouchData: const LineTouchData(enabled: false),
        gridData: FlGridData(
          show: true, drawVerticalLine: false,
          horizontalInterval: ((maxY - minY) / 4).clamp(0.5, double.infinity),
          getDrawingHorizontalLine: (v) =>
              const FlLine(color: Color(0xFF2A2A2A), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 36,
            getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(0),
                style: const TextStyle(color: Colors.grey, fontSize: 10)),
          )),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 26, interval: 1,
            getTitlesWidget: (value, meta) {
              final i = value.toInt();
              if (i < 0 || i >= _weightEntries.length) return const SizedBox.shrink();
              final parts = (_weightEntries[i]['date'] as String).split('-');
              final label = parts.length == 3 ? '${parts[1]}/${parts[2]}' : '';
              return Padding(padding: const EdgeInsets.only(top: 6),
                  child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9)));
            },
          )),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [LineChartBarData(
          spots: spots, isCurved: true, color: Colors.tealAccent, barWidth: 2.5,
          dotData: FlDotData(show: true,
            getDotPainter: (s, pct, bar, idx) =>
                FlDotCirclePainter(radius: 3, color: Colors.tealAccent, strokeWidth: 0)),
          belowBarData: BarAreaData(show: true, color: Colors.tealAccent.withOpacity(0.12)),
        )],
      )),
    );
  }

  Widget _dot(Color c, String l) => Row(children: [
    Container(width:10,height:10,
        decoration: BoxDecoration(color:c,shape:BoxShape.circle)),
    const SizedBox(width:4),
    Text(l, style: const TextStyle(fontSize:10,color:Colors.grey)),
  ]);
}