import 'package:flutter/material.dart';
import '../diary_db.dart';
import '../services/api_service.dart';

class TDEETab extends StatefulWidget {
  const TDEETab({super.key});

  @override
  State<TDEETab> createState() => _TDEETabState();
}

class _TDEETabState extends State<TDEETab> {
  bool _isLoading = false;
  Map<String, dynamic>? _data;
  String? _error;
  double? _currentWeight;

  // Macro sliders (fractions, always sum to 1.0)
  double _pPct = 0.30; // protein
  double _cPct = 0.35; // carbs
  double _fPct = 0.35; // fat
  String? _locked; // 'protein' | 'carbs' | 'fat' | null

  // Goal
  bool _goalOn = false;
  final _gwCtrl = TextEditingController(); // goal weight
  final _wkCtrl = TextEditingController(); // goal weeks

  static const double _tefP = 0.25;
  static const double _tefC = 0.08;
  static const double _tefF = 0.03;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _gwCtrl.dispose();
    _wkCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });

    final dbData = await DiaryDatabase.instance.getDataForTDEE();
    _currentWeight = dbData['latest_weight'];

    final result = await ApiService.estimateTdee(
      dailyEntries:  List<Map<String,dynamic>>.from(dbData['daily_entries']),
      weightEntries: List<Map<String,dynamic>>.from(dbData['weight_entries']),
    );

    if (result != null && result['success'] == true) {
      setState(() {
        _data  = result;
        _pPct  = (result['avg_protein_pct'] as num).toDouble();
        _cPct  = (result['avg_carbs_pct']   as num).toDouble();
        _fPct  = (result['avg_fat_pct']     as num).toDouble();
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result['error_message'] as String?
          ?? result['error'] as String?
          ?? 'Could not connect to server.';
        _isLoading = false;
  });
}
  }

  // ── Slider logic ───────────────────────────────────────────────
  void _onChange(String macro, double val) {
    if (_locked == macro) return;
    double p = _pPct, c = _cPct, f = _fPct;
    final delta = val - (macro=='protein' ? p : macro=='carbs' ? c : f);

    void absorbInto(String target, double d) {
      if (target=='protein') p = (p - d).clamp(0.05, 0.85);
      else if (target=='carbs') c = (c - d).clamp(0.05, 0.85);
      else f = (f - d).clamp(0.05, 0.85);
    }

    void proportional(String a, String b, double d) {
      final totalOther = (a=='protein'?p:a=='carbs'?c:f) +
                         (b=='protein'?p:b=='carbs'?c:f);
      if (totalOther > 0) {
        absorbInto(a, d * ((a=='protein'?p:a=='carbs'?c:f)/totalOther));
        absorbInto(b, d * ((b=='protein'?p:b=='carbs'?c:f)/totalOther));
      }
    }

    if (macro == 'protein') { p = val;
      if (_locked == 'carbs') absorbInto('fat',    delta);
      else if (_locked == 'fat')  absorbInto('carbs',  delta);
      else proportional('carbs', 'fat', delta);
    } else if (macro == 'carbs') { c = val;
      if (_locked == 'protein') absorbInto('fat',     delta);
      else if (_locked == 'fat')    absorbInto('protein', delta);
      else proportional('protein', 'fat', delta);
    } else { f = val;
      if (_locked == 'protein') absorbInto('carbs',   delta);
      else if (_locked == 'carbs')  absorbInto('protein', delta);
      else proportional('protein', 'carbs', delta);
    }

    final sum = p + c + f;
    setState(() { _pPct = p/sum; _cPct = c/sum; _fPct = f/sum; });
  }

  // ── TEF-adjusted recommendation ────────────────────────────────
  Map<String, double> get _rec {
    if (_data == null) return {};
    final tdee    = (_data!['current_tdee']    as num).toDouble();
    final avgP    = (_data!['avg_protein_pct'] as num).toDouble();
    final avgC    = (_data!['avg_carbs_pct']   as num).toDouble();
    final avgF    = (_data!['avg_fat_pct']     as num).toDouble();

    final kCurr   = avgP*_tefP + avgC*_tefC + avgF*_tefF;
    final netTDEE = tdee * (1 - kCurr);
    final kNew    = _pPct*_tefP + _cPct*_tefC + _fPct*_tefF;

    double deficit = 0;
    if (_goalOn && _currentWeight != null) {
      final gw = double.tryParse(_gwCtrl.text) ?? 0;
      final wk = int.tryParse(_wkCtrl.text) ?? 0;
      if (gw > 0 && wk > 0) deficit = (_currentWeight! - gw) * 3500 / (wk * 7);
    }

    final targetNet = netTDEE - deficit;
    if (1 - kNew < 0.01) return {};
    final gross = targetNet / (1 - kNew);

    return {
      'gross':   gross,
      'protein': _pPct * gross / 4,
      'carbs':   _cPct * gross / 4,
      'fat':     _fPct * gross / 9,
      'tef':     gross * kNew,
      'net':     targetNet,
    };
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.tealAccent),
          SizedBox(height: 16),
          Text('Running regression…', style: TextStyle(color: Colors.grey)),
        ],
      ));
    }

    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _load,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
            child: const Text('Retry'),
          ),
        ]),
      ));
    }

    if (_data == null) {
      return const Center(
          child: Text('No data.', style: TextStyle(color: Colors.grey)));
    }

    final currTDEE  = (_data!['current_tdee']      as num).toDouble();
    final prevTDEE  = (_data!['previous_tdee']      as num).toDouble();
    final chgDate   =  _data!['change_date']        as String;
    final r2        = (_data!['current_r_squared']  as num).toDouble();
    final days      =  _data!['days_analyzed']      as int;
    final history   = List<Map<String,dynamic>>.from(_data!['tdee_history']);
    final rec       = _rec;

    return RefreshIndicator(
      onRefresh: _load,
      color: Colors.tealAccent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── TDEE Summary ────────────────────────────────────────
          _sec('ESTIMATED TDEE'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _tdeeCard('Current',  currTDEE, Colors.tealAccent)),
            const SizedBox(width: 8),
            Expanded(child: _tdeeCard('Previous', prevTDEE, Colors.grey)),
          ]),
          const SizedBox(height: 6),
          _info(Icons.timeline,          'TDEE shift detected around $chgDate'),
          _info(Icons.analytics_outlined,
              'Data quality: ${(r2*100).toStringAsFixed(0)}% R²  •  $days days'),
          const SizedBox(height: 16),

          // ── Macro sliders ───────────────────────────────────────
          _sec('MACRO DISTRIBUTION'),
          const SizedBox(height: 4),
          const Text('Adjust macros to explore TEF-adjusted calorie targets. '
              'Lock one macro to keep it fixed.',
              style: TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 8),
          Card(child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              _slider('Protein', 'protein', _pPct, Colors.tealAccent),
              const SizedBox(height: 8),
              _slider('Carbs',   'carbs',   _cPct, Colors.lightBlueAccent),
              const SizedBox(height: 8),
              _slider('Fat',     'fat',     _fPct, Colors.pinkAccent),
              const SizedBox(height: 8),
              Text(
                'P:${(_pPct*100).toStringAsFixed(0)}%  '
                'C:${(_cPct*100).toStringAsFixed(0)}%  '
                'F:${(_fPct*100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 11, color: Colors.grey,
                    fontFamily: 'monospace'),
              ),
            ]),
          )),
          const SizedBox(height: 16),

          // ── Goal ────────────────────────────────────────────────
          Row(children: [
            Checkbox(
              value: _goalOn,
              activeColor: Colors.tealAccent,
              checkColor: Colors.black,
              onChanged: (v) => setState(() => _goalOn = v ?? false),
            ),
            const Text('Set a weight goal'),
          ]),
          if (_goalOn) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(
                controller: _gwCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Target weight', suffixText: 'lbs',
                  filled: true, fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(child: TextField(
                controller: _wkCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Timeframe', suffixText: 'weeks',
                  filled: true, fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )),
            ]),
          ],
          const SizedBox(height: 16),

          // ── Recommendation ──────────────────────────────────────
          if (rec.isNotEmpty) ...[
            _sec(_goalOn ? 'RECOMMENDATION FOR GOAL' : 'MAINTENANCE'),
            const SizedBox(height: 8),
            Card(
              color: const Color(0xFF1A2A2A),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(rec['gross']!.toStringAsFixed(0),
                          style: const TextStyle(fontSize: 38,
                              fontWeight: FontWeight.bold,
                              color: Colors.tealAccent)),
                      const SizedBox(width: 6),
                      const Text('kcal/day',
                          style: TextStyle(fontSize: 14, color: Colors.grey)),
                    ]),
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                      _gramCard('Protein', rec['protein']!, Colors.tealAccent),
                      _gramCard('Carbs',   rec['carbs']!,   Colors.lightBlueAccent),
                      _gramCard('Fat',     rec['fat']!,     Colors.pinkAccent),
                    ]),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFF2A2A2A)),
                    const SizedBox(height: 6),
                    _recRow('TEF (digestion burn)',
                        '${rec['tef']!.toStringAsFixed(0)} kcal'),
                    _recRow('Net available energy',
                        '${rec['net']!.toStringAsFixed(0)} kcal'),
                    if (_goalOn && _currentWeight != null) ...[
                      const SizedBox(height: 8),
                      Text(_goalSummary(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11, color: Colors.grey,
                              fontStyle: FontStyle.italic)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '⚡ Higher protein % raises TEF — you burn more digesting food, '
              'so the gross calorie target rises while net energy stays the same.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
          const SizedBox(height: 16),

          // ── TDEE history ────────────────────────────────────────
          if (history.isNotEmpty) ...[
            _sec('HISTORICAL TDEE (14-day rolling)'),
            const SizedBox(height: 8),
            Card(child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: history.map((e) {
                final tdee = (e['tdee'] as num).toDouble();
                final date = (e['date'] as String).substring(5); // MM-DD
                final norm = ((tdee - (currTDEE - 500)) / 1000).clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    SizedBox(width: 40,
                        child: Text(date,
                            style: const TextStyle(fontSize: 9, color: Colors.grey))),
                    Expanded(child: LinearProgressIndicator(
                      value: norm, minHeight: 5,
                      backgroundColor: const Color(0xFF2A2A2A),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          tdee > currTDEE ? Colors.orangeAccent : Colors.tealAccent),
                    )),
                    SizedBox(width: 46,
                        child: Text('${tdee.toStringAsFixed(0)}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 9, color: Colors.grey,
                                fontFamily: 'monospace'))),
                  ]),
                );
              }).toList()),
            )),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Helper widgets ─────────────────────────────────────────────
  String _goalSummary() {
    final gw = double.tryParse(_gwCtrl.text) ?? 0;
    final wk = int.tryParse(_wkCtrl.text) ?? 0;
    if (gw <= 0 || wk <= 0 || _currentWeight == null) return '';
    final diff = _currentWeight! - gw;
    final dir  = diff > 0 ? 'lose' : 'gain';
    return '$dir ${diff.abs().toStringAsFixed(1)} lbs over $wk weeks '
        '(${(diff.abs()/wk).toStringAsFixed(2)} lbs/week)';
  }

  Widget _sec(String t) => Text(t,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
          color: Colors.grey, letterSpacing: 1.2));

  Widget _info(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(children: [
      Icon(icon, size: 13, color: Colors.grey),
      const SizedBox(width: 4),
      Expanded(child: Text(text,
          style: const TextStyle(fontSize: 11, color: Colors.grey))),
    ]),
  );

  Widget _tdeeCard(String label, double val, Color color) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 6),
        Text('${val.toStringAsFixed(0)} kcal',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                color: color)),
      ]),
    ),
  );

  Widget _slider(String label, String key, double val, Color color) {
    final locked = _locked == key;
    return Row(children: [
      SizedBox(width: 52,
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.grey))),
      Expanded(child: Slider(
        value: val.clamp(0.05, 0.70),
        min: 0.05, max: 0.70,
        activeColor:   locked ? Colors.grey : color,
        inactiveColor: const Color(0xFF2A2A2A),
        onChanged:     locked ? null : (v) => _onChange(key, v),
      )),
      SizedBox(width: 36,
          child: Text('${(val*100).toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 11, color: color,
                  fontFamily: 'monospace'))),
      const SizedBox(width: 4),
      GestureDetector(
        onTap: () => setState(() => _locked = locked ? null : key),
        child: Icon(
          locked ? Icons.lock : Icons.lock_open,
          size: 18,
          color: locked ? Colors.tealAccent : Colors.grey,
        ),
      ),
    ]);
  }

  Widget _gramCard(String label, double grams, Color color) => Column(children: [
    Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    const SizedBox(height: 4),
    Text('${grams.toStringAsFixed(0)}g',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
            color: color, fontFamily: 'monospace')),
  ]);

  Widget _recRow(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      Text(value,  style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
    ],
  );
}