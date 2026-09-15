import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_label.dart';
import '../data/food_search_service.dart';
import '../data/nutrition_repository.dart';
import '../data/recipe_repository.dart';
import '../domain/catalog_food.dart';
import '../domain/food_entry.dart';
import '../domain/food_search_result.dart';
import 'food_picker.dart';
import 'scan_food_screen.dart';

class LogFoodScreen extends StatefulWidget {
  const LogFoodScreen({
    super.key,
    required this.uid,
    required this.nutritionRepository,
    required this.searchService,
    required this.recipeRepository,
    required this.date,
    required this.onSaved,
  });

  final String uid;
  final NutritionRepository nutritionRepository;
  final FoodSearchService searchService;
  final RecipeRepository recipeRepository;

  /// The day the logged entries belong to — the day currently being viewed
  /// on the nutrition home screen, which is not necessarily today.
  final DateTime date;
  final VoidCallback onSaved;

  @override
  State<LogFoodScreen> createState() => _LogFoodScreenState();
}

class _LogFoodScreenState extends State<LogFoodScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 3, vsync: this);
  final _quantityController = TextEditingController(text: '100');
  final _naturalLanguageController = TextEditingController();

  MealType _mealType = MealType.breakfast;
  FoodSearchResult? _selectedFood;
  List<ParsedFoodItem> _parsedItems = [];
  File? _pickedImage;
  bool _saving = false;
  bool _analyzingImage = false;
  String? _error;
  late Future<List<CatalogItem>> _catalogFuture;
  late Future<List<FoodEntry>> _entriesFuture;
  late Future<NutritionGoals?> _goalsFuture;

  @override
  void initState() {
    super.initState();
    _catalogFuture = _loadCatalog();
    _entriesFuture = widget.nutritionRepository.listFoodLog(widget.uid);
    _goalsFuture = widget.nutritionRepository.getGoals(widget.uid);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Re-fetches just this screen's own "TODAY" summary (entries + goals)
  /// after a log or a removal — separate from [widget.onSaved], which pops
  /// this screen on a real "log a food" action and must not fire on a mere
  /// in-place removal.
  void _refreshToday() {
    if (!mounted) return;
    setState(() {
      _entriesFuture = widget.nutritionRepository.listFoodLog(widget.uid);
      _catalogFuture = _loadCatalog();
    });
  }

  Future<void> _removeEntry(FoodEntry entry) async {
    await widget.nutritionRepository.deleteFoodEntry(widget.uid, entry.id);
    _refreshToday();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _quantityController.dispose();
    _naturalLanguageController.dispose();
    super.dispose();
  }

  Future<List<CatalogItem>> _loadCatalog() async {
    final recent = await widget.nutritionRepository.listFoodLog(widget.uid);
    final recipes = await widget.recipeRepository.list(widget.uid);
    return buildFrequentFoods(recentLogNewestFirst: recent, recipes: recipes);
  }

  Future<void> _logCatalogItem(CatalogItem item) async {
    await widget.nutritionRepository.logFood(
      uid: widget.uid,
      date: widget.date,
      mealType: _mealType,
      foodName: item.name,
      quantityGrams: item.quantityGrams == 0 ? 1 : item.quantityGrams,
      calories: item.calories,
      proteinG: item.proteinG,
      carbsG: item.carbsG,
      fatG: item.fatG,
      source: item.source,
    );
    _refreshToday();
    widget.onSaved();
  }

  void _openScan() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScanFoodScreen(
          uid: widget.uid,
          nutritionRepository: widget.nutritionRepository,
          searchService: widget.searchService,
          recipeRepository: widget.recipeRepository,
          date: widget.date,
          onLogged: widget.onSaved,
        ),
      ),
    );
  }

  Future<void> _parseNaturalLanguage() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final items = await widget.searchService.parseText(_naturalLanguageController.text);
      if (!mounted) return;
      setState(() => _parsedItems = items);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not parse that. Try again or use search instead.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAndAnalyzeImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    setState(() {
      _pickedImage = File(picked.path);
      _analyzingImage = true;
      _error = null;
    });
    try {
      final bytes = await picked.readAsBytes();
      final mimeType = picked.mimeType ?? 'image/jpeg';
      final items = await widget.searchService.parseImage(bytes, mimeType);
      if (!mounted) return;
      setState(() => _parsedItems = items);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = "Could not analyze that photo. Try again or describe it instead.");
    } finally {
      if (mounted) setState(() => _analyzingImage = false);
    }
  }

  Future<void> _saveSelectedFood() async {
    final food = _selectedFood;
    final grams = double.tryParse(_quantityController.text);
    if (food == null || grams == null || grams <= 0) return;

    setState(() => _saving = true);
    final scale = grams / 100;
    widget.nutritionRepository
        .logFood(
          uid: widget.uid,
          date: widget.date,
          mealType: _mealType,
          foodName: food.name,
          quantityGrams: grams,
          calories: food.caloriesPer100g * scale,
          proteinG: food.proteinPer100g * scale,
          carbsG: food.carbsPer100g * scale,
          fatG: food.fatPer100g * scale,
          source: food.source,
        )
        .then((_) {}, onError: (Object error) => debugPrint('Failed to log food: $error'));
    if (!mounted) return;
    setState(() => _saving = false);
    _refreshToday();
    widget.onSaved();
  }

  Future<void> _saveParsedItems() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    // Items that failed nutrition lookup are kept (not just counted) so a
    // retry only re-attempts what's actually left to resolve, instead of
    // re-saving items that already succeeded.
    final failedItems = <ParsedFoodItem>[];
    var savedItems = 0;
    try {
      for (final item in _parsedItems) {
        // Mirror the `grams <= 0` guard in _saveSelectedFood: a malformed
        // LLM-parsed quantity must not reach Firestore, since it would make
        // per-gram macro rates (calories/quantityGrams etc.) undefined for
        // any later edit of this entry.
        if (item.estimatedQuantityGrams <= 0) continue;

        FoodSearchResult resolved;
        try {
          final matches = await widget.searchService.search(widget.uid, item.foodName);
          resolved = matches.isNotEmpty
              ? matches.first
              : await widget.searchService.estimateNutrition(item.foodName);
        } catch (_) {
          try {
            resolved = await widget.searchService.estimateNutrition(item.foodName);
          } catch (_) {
            // Both search and the LLM estimate failed for this item (offline,
            // or every provider rate-limited). Skip just this item and keep
            // saving the rest rather than discarding the whole parsed batch;
            // the user is told below how many items were dropped.
            failedItems.add(item);
            continue;
          }
        }
        final scale = item.estimatedQuantityGrams / 100;
        // Fire-and-handle-errors rather than awaited: Firestore's offline
        // persistence updates the local cache immediately but the returned
        // Future doesn't resolve until the server acks, which never happens
        // offline — awaiting it here would hang this loop (and the UI)
        // indefinitely with no connectivity. The resolve-macros calls above
        // are Cloud Function calls and inherently require connectivity
        // already, so only this final write needs the fire-and-forget
        // treatment.
        widget.nutritionRepository
            .logFood(
              uid: widget.uid,
              date: widget.date,
              mealType: _mealType,
              foodName: item.foodName,
              quantityGrams: item.estimatedQuantityGrams,
              calories: resolved.caloriesPer100g * scale,
              proteinG: resolved.proteinPer100g * scale,
              carbsG: resolved.carbsPer100g * scale,
              fatG: resolved.fatPer100g * scale,
              source: resolved.source,
            )
            .then((_) {}, onError: (Object error) => debugPrint('Failed to log food: $error'));
        savedItems++;
      }
    } catch (error) {
      // Anything unexpected outside the per-item handling above. Surface it
      // instead of letting it escape and strand the UI on the spinner.
      if (mounted) {
        setState(() => _error = 'Could not save those items. Please try again.');
      }
      return;
    } finally {
      // Always runs, so the spinner can never be left up permanently.
      if (mounted) setState(() => _saving = false);
    }

    if (!mounted) return;

    if (failedItems.isNotEmpty || savedItems == 0) {
      // Something didn't make it to Firestore. Stay on this screen instead
      // of calling onSaved() — the caller's onSaved pops immediately, which
      // would tear this screen down in the same frame the message is set,
      // so it would never actually be seen. Only the unresolved items are
      // kept in the list, so tapping "Save all" again doesn't re-save what
      // already succeeded.
      final String message;
      if (savedItems == 0 && failedItems.isEmpty) {
        message = "Those items didn't have a valid quantity to log. "
            'Try describing the portion size.';
      } else if (savedItems == 0) {
        message = 'Could not look up nutrition for those items. Please try again.';
      } else {
        message =
            'Saved $savedItems item(s), but could not look up nutrition for ${failedItems.length}. Retry the rest below.';
      }
      setState(() {
        _parsedItems = failedItems;
        _error = message;
      });
      _refreshToday();
      return;
    }

    _refreshToday();
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text('Log food', style: Theme.of(context).textTheme.headlineMedium),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _GlassTabBar(controller: _tabController),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSearchTab(),
                    _buildNaturalLanguageTab(),
                    _buildPhotoTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        // A single FoodPicker instance owns both the search field and its
        // results list (its own internal search state can't be split
        // without duplicating it) — with expandResults: false, the results
        // shrink-wrap to their content so they drop in directly under the
        // field, and the TODAY summary / Frequent Foods below sit in the
        // idle (empty-query) state exactly as the screenshot shows.
        FoodPicker(
          uid: widget.uid,
          searchService: widget.searchService,
          onScanTap: _openScan,
          onSelected: (result) => setState(() => _selectedFood = result),
          expandResults: false,
        ),
        const SizedBox(height: 16),
        _TodaySummaryCard(
          entriesFuture: _entriesFuture,
          goalsFuture: _goalsFuture,
          date: widget.date,
          isSameDay: _isSameDay,
          onRemove: _removeEntry,
        ),
        const SizedBox(height: 16),
        _FrequentFoodsRow(future: _catalogFuture, onTap: _logCatalogItem),
        const SizedBox(height: 16),
        _MealTypeRow(value: _mealType, onChanged: (m) => setState(() => _mealType = m)),
        if (_selectedFood != null) ...[
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedFood!.name,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('quantityGramsField'),
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Quantity (grams)',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        _saving
            ? const Center(child: CircularProgressIndicator())
            : PrimaryButton(
                label: 'Save',
                onPressed: _selectedFood == null ? null : _saveSelectedFood,
              ),
      ],
    );
  }

  Widget _buildNaturalLanguageTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _MealTypeRow(value: _mealType, onChanged: (m) => setState(() => _mealType = m)),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _naturalLanguageController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Describe what you ate',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _parseNaturalLanguage, child: const Text('Parse')),
            ],
          ),
        ),
        _buildParsedItemsReview(),
      ],
    );
  }

  Widget _buildPhotoTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _MealTypeRow(value: _mealType, onChanged: (m) => setState(() => _mealType = m)),
        const SizedBox(height: 16),
        if (_pickedImage != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(_pickedImage!, height: 180, fit: BoxFit.cover),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Camera'),
                onPressed: _analyzingImage ? null : () => _pickAndAnalyzeImage(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Gallery'),
                onPressed: _analyzingImage ? null : () => _pickAndAnalyzeImage(ImageSource.gallery),
              ),
            ),
          ],
        ),
        if (_analyzingImage) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ],
        _buildParsedItemsReview(),
      ],
    );
  }

  /// Shared by the Describe and Photo tabs: the parsed-items list plus the
  /// error message and "Save all" button, since both flows populate the
  /// same [_parsedItems] state and save through [_saveParsedItems].
  Widget _buildParsedItemsReview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.error),
          ),
        ],
        const SizedBox(height: 16),
        for (final item in _parsedItems)
          GlassCard(
            child: Text('${item.foodName} — ${item.estimatedQuantityGrams.toStringAsFixed(0)}g'),
          ),
        const SizedBox(height: 24),
        _saving
            ? const Center(child: CircularProgressIndicator())
            : PrimaryButton(
                label: 'Save all',
                onPressed: _parsedItems.isEmpty ? null : _saveParsedItems,
              ),
      ],
    );
  }
}

/// A horizontal row of tap-to-log cards per the handoff's "FREQUENT FOODS"
/// section — the user's most-recently-logged foods, their saved recipes,
/// then a static Indian-first seed catalog to fill it out (see
/// `buildFrequentFoods`). Tapping a card logs it immediately at its listed
/// serving, skipping the quantity/save flow — it's meant to be one tap.
class _FrequentFoodsRow extends StatelessWidget {
  const _FrequentFoodsRow({required this.future, required this.onTap});

  final Future<List<CatalogItem>> future;
  final ValueChanged<CatalogItem> onTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CatalogItem>>(
      future: future,
      builder: (context, snapshot) {
        final items = snapshot.data;
        if (items == null || items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Frequent foods'),
            const SizedBox(height: 10),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Pressable(
                    onTap: () => onTap(item),
                    child: SizedBox(
                      width: 130,
                      child: GlassCard(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.tag != null)
                              Text(
                                item.tag!.toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.accentGreen,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 13),
                            ),
                            const Spacer(),
                            Text(
                              '${item.calories.toStringAsFixed(0)} kcal',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A compact glass segmented pill row for choosing the meal a food gets
/// logged under. The design handoff's Log food screenshot doesn't show a
/// meal-type control (it likely lives one step later in the real Figma
/// flow, off this crop) — logging is meaningless without one, so it's kept
/// here, restyled to the glass system rather than dropped. See
/// docs/superpowers/ISSUES.md.
class _MealTypeRow extends StatelessWidget {
  const _MealTypeRow({required this.value, required this.onChanged});

  final MealType value;
  final ValueChanged<MealType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final meal in MealType.values) ...[
          Expanded(
            child: Pressable(
              onTap: () => onChanged(meal),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: value == meal
                      ? AppColors.accentGreen.withValues(alpha: 0.18)
                      : AppColors.glassFill,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: value == meal
                        ? AppColors.accentGreen.withValues(alpha: 0.45)
                        : AppColors.glassStroke,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    '${meal.name[0].toUpperCase()}${meal.name.substring(1)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: value == meal ? AppColors.accentGreen : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (meal != MealType.values.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

/// The Search tab's "TODAY · {kcal} kcal" glass card — the day's already
/// logged items (real, from [entriesFuture]/[isSameDay] filtering to
/// [date], never fabricated) with a per-item remove action, closing with a
/// coaching line computed from the same totals-vs-goal math the nutrition
/// home screen already uses.
class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({
    required this.entriesFuture,
    required this.goalsFuture,
    required this.date,
    required this.isSameDay,
    required this.onRemove,
  });

  final Future<List<FoodEntry>> entriesFuture;
  final Future<NutritionGoals?> goalsFuture;
  final DateTime date;
  final bool Function(DateTime, DateTime) isSameDay;
  final ValueChanged<FoodEntry> onRemove;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FoodEntry>>(
      future: entriesFuture,
      builder: (context, entriesSnapshot) {
        final allEntries = entriesSnapshot.data;
        if (allEntries == null) return const SizedBox.shrink();
        final entries = allEntries.where((e) => isSameDay(e.date, date)).toList();
        final totalCalories = entries.fold<double>(0, (sum, e) => sum + e.calories);
        final totalProtein = entries.fold<double>(0, (sum, e) => sum + e.proteinG);

        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'TODAY · ${totalCalories.toStringAsFixed(0)} kcal',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.mono(color: AppColors.accentGreen, fontSize: 13),
                    ),
                  ),
                  Text(
                    '${entries.length} item${entries.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              if (entries.isEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Nothing logged yet today.',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ] else ...[
                for (final entry in entries) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.foodName,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_mealLabel(entry.mealType)} · '
                              '${entry.proteinG.toStringAsFixed(0)}P · '
                              '${entry.carbsG.toStringAsFixed(0)}C · '
                              '${entry.fatG.toStringAsFixed(0)}F',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        entry.calories.toStringAsFixed(0),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Pressable(
                        onTap: () => onRemove(entry),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(
                            color: AppColors.glassFillStrong,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 14, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              FutureBuilder<NutritionGoals?>(
                future: goalsFuture,
                builder: (context, goalsSnapshot) {
                  final goals = goalsSnapshot.data;
                  if (goals == null) return const SizedBox.shrink();
                  final kcalLeft = goals.dailyCalories - totalCalories;
                  final proteinLeft = goals.proteinG - totalProtein;
                  final over = kcalLeft <= 0;
                  return Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      over
                          ? "You're over target for today. Tomorrow is a fresh sheet."
                          : '${kcalLeft.round()} kcal and ${proteinLeft.clamp(0, double.infinity).round()}g '
                              'protein still to go today',
                      style: TextStyle(
                        color: over ? AppColors.error : AppColors.accentGreen,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _mealLabel(MealType meal) => '${meal.name[0].toUpperCase()}${meal.name.substring(1)}';
}

/// The floating glass pill tab bar shared by the Search/Describe/Photo tabs
/// — stadium geometry, glass fill, selected tab lit green, per the shared
/// conventions in the handoff plan.
class _GlassTabBar extends StatelessWidget {
  const _GlassTabBar({required this.controller});

  final TabController controller;

  static const _labels = ['Search', 'Describe', 'Photo'];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.glassStroke),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                for (var i = 0; i < _labels.length; i++)
                  Expanded(
                    child: Pressable(
                      onTap: () => controller.animateTo(i),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: controller.index == i
                              ? AppColors.accentGreen.withValues(alpha: 0.18)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            _labels[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: controller.index == i
                                  ? AppColors.accentGreen
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
