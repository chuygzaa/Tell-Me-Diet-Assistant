import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';

class FoodPickResult {
  final bool isCustom;
  final Map<String, dynamic>? food;
  const FoodPickResult.database(this.food) : isCustom = false;
  const FoodPickResult.custom()
      : isCustom = true,
        food = null;
}

Future<FoodPickResult?> showFoodPicker(BuildContext context) {
  return showModalBottomSheet<FoodPickResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1A1A1A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _FoodPickerSheet(),
  );
}

class _FoodPickerSheet extends StatefulWidget {
  const _FoodPickerSheet();
  @override
  State<_FoodPickerSheet> createState() => _FoodPickerSheetState();
}

class _FoodPickerSheetState extends State<_FoodPickerSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final res = await ApiService.searchFoods(q.trim());
      if (!mounted) return;
      setState(() {
        _results = res;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Food',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Search foods…',
                prefixIcon: const Icon(Icons.search),
                filled: true, fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            _searchController.text.trim().length < 2
                                ? 'Type at least 2 characters'
                                : 'No matches found',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _results.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: Color(0xFF2A2A2A)),
                          itemBuilder: (_, i) {
                            final f = _results[i];
                            final per100 =
                                (f['per_100g'] as Map).cast<String, dynamic>();
                            final cals =
                                (per100['calories'] as num?)?.toDouble() ?? 0;
                            return ListTile(
                              title: Text(f['food_name_full'] as String,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14)),
                              subtitle: Text(
                                  '${cals.toStringAsFixed(0)} kcal / 100g',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                              onTap: () => Navigator.pop(
                                  context, FoodPickResult.database(f)),
                            );
                          },
                        ),
            ),
            const Divider(color: Color(0xFF2A2A2A)),
            TextButton.icon(
              onPressed: () =>
                  Navigator.pop(context, const FoodPickResult.custom()),
              icon: const Icon(Icons.add_circle_outline,
                  color: Colors.tealAccent),
              label: const Text('Create custom food',
                  style: TextStyle(color: Colors.tealAccent)),
            ),
          ],
        ),
      ),
    );
  }
}