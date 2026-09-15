import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/food_search_service.dart';
import '../domain/food_entry.dart';
import '../domain/food_search_result.dart';

class FoodPicker extends StatefulWidget {
  const FoodPicker({
    super.key,
    required this.uid,
    required this.searchService,
    required this.onSelected,
    this.onScanTap,
    this.expandResults = true,
  });

  final String uid;
  final FoodSearchService searchService;
  final ValueChanged<FoodSearchResult> onSelected;

  /// Renders a "Scan" pill beside the search field when provided — the Log
  /// food Search tab's shell per the design handoff (Screen 7); omitted
  /// wherever this picker is embedded without a scan flow.
  final VoidCallback? onScanTap;

  /// True (the default) fills remaining vertical space with the results
  /// list, as when this picker is the only content on screen. Log food's
  /// Search tab passes false so the results shrink-wrap to their content
  /// instead, letting the TODAY summary and Frequent Foods sit in the same
  /// scroll view right below the search field.
  final bool expandResults;

  @override
  State<FoodPicker> createState() => _FoodPickerState();
}

class _FoodPickerState extends State<FoodPicker> {
  final _controller = TextEditingController();
  List<FoodSearchResult> _results = [];

  /// Incremented per search; a response is only applied if it belongs to
  /// the most recent request, so a slow early query can't clobber a newer one.
  int _searchToken = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    final token = ++_searchToken;
    try {
      final results = await widget.searchService.search(widget.uid, query);
      if (!mounted || token != _searchToken) return;
      setState(() => _results = results);
    } catch (error) {
      debugPrint('Food search failed: $error');
    }
  }

  Future<void> _addCustom(String name) async {
    // A custom food's macros are entered on the dedicated add-custom form
    // this picker navigates to, not inline here, since the form needs
    // several numeric fields.
    final repository = widget.searchService.customFoodRepository;
    final macros = await Navigator.of(context).push<Map<String, double>>(
      MaterialPageRoute(builder: (_) => _AddCustomFoodForm(name: name)),
    );
    if (macros == null) return;
    final food = await repository.addCustom(
      widget.uid,
      name: name,
      caloriesPer100g: macros['calories']!,
      proteinPer100g: macros['protein']!,
      carbsPer100g: macros['carbs']!,
      fatPer100g: macros['fat']!,
    );
    widget.onSelected(FoodSearchResult(
      name: food.name,
      source: FoodSource.custom,
      caloriesPer100g: food.caloriesPer100g,
      proteinPer100g: food.proteinPer100g,
      carbsPer100g: food.carbsPer100g,
      fatPer100g: food.fatPer100g,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();

    return Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.glassFill,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.glassStroke),
                  ),
                  child: TextField(
                    key: const Key('foodSearchField'),
                    controller: _controller,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Search foods or recipes',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    onChanged: _search,
                  ),
                ),
              ),
              if (widget.onScanTap != null) ...[
                const SizedBox(width: 10),
                _ScanPill(onTap: widget.onScanTap!),
              ],
            ],
          ),
          _buildResultsList(query),
        ],
      ),
    );
  }

  Widget _buildResultsList(String query) {
    final items = [
      for (final result in _results)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              result.name,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${result.caloriesPer100g.toStringAsFixed(0)} kcal/100g',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            onTap: () => widget.onSelected(result),
          ),
        ),
      if (query.isNotEmpty)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.add_circle_outline, color: AppColors.accentGreen),
          title: Text(
            'Add "$query"',
            style: const TextStyle(color: AppColors.accentGreen, fontWeight: FontWeight.w600),
          ),
          onTap: () => _addCustom(query),
        ),
    ];

    if (widget.expandResults) {
      return Expanded(child: ListView(padding: const EdgeInsets.only(top: 12), children: items));
    }
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items),
    );
  }
}

/// The green stadium "Scan" pill beside the search field (Screen 7/8 of the
/// handoff) — opens barcode scanning.
class _ScanPill extends StatelessWidget {
  const _ScanPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accentGreen,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_scanner, size: 18, color: Colors.black),
              SizedBox(width: 6),
              Text(
                'Scan',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddCustomFoodForm extends StatefulWidget {
  const _AddCustomFoodForm({required this.name});

  final String name;

  @override
  State<_AddCustomFoodForm> createState() => _AddCustomFoodFormState();
}

class _AddCustomFoodFormState extends State<_AddCustomFoodForm> {
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  void _save() {
    final calories = double.tryParse(_caloriesController.text);
    final protein = double.tryParse(_proteinController.text);
    final carbs = double.tryParse(_carbsController.text);
    final fat = double.tryParse(_fatController.text);
    if (calories == null || protein == null || carbs == null || fat == null) return;
    Navigator.of(context).pop({
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add "${widget.name}"')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _caloriesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Calories per 100g'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _proteinController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Protein (g) per 100g'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _carbsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Carbs (g) per 100g'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _fatController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Fat (g) per 100g'),
                ),
                const SizedBox(height: 24),
                PrimaryButton(label: 'Save', onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
