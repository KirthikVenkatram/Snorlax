import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/food_search_service.dart';
import '../data/nutrition_repository.dart';
import '../domain/food_entry.dart';
import '../domain/food_search_result.dart';
import 'food_picker.dart';

class LogFoodScreen extends StatefulWidget {
  const LogFoodScreen({
    super.key,
    required this.uid,
    required this.nutritionRepository,
    required this.searchService,
    required this.date,
    required this.onSaved,
  });

  final String uid;
  final NutritionRepository nutritionRepository;
  final FoodSearchService searchService;

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

  @override
  void dispose() {
    _tabController.dispose();
    _quantityController.dispose();
    _naturalLanguageController.dispose();
    super.dispose();
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
      return;
    }

    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log food'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Search'), Tab(text: 'Describe'), Tab(text: 'Photo')],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildSearchTab(),
            _buildNaturalLanguageTab(),
            _buildPhotoTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButton<MealType>(
            value: _mealType,
            items: MealType.values
                .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
                .toList(),
            onChanged: (m) => setState(() => _mealType = m ?? _mealType),
          ),
          const SizedBox(height: 16),
          if (_selectedFood != null) ...[
            GlassCard(child: Text(_selectedFood!.name)),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: FoodPicker(
              uid: widget.uid,
              searchService: widget.searchService,
              onSelected: (result) => setState(() => _selectedFood = result),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('quantityGramsField'),
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Quantity (grams)'),
          ),
          const SizedBox(height: 24),
          _saving
              ? const Center(child: CircularProgressIndicator())
              : PrimaryButton(
                  label: 'Save',
                  onPressed: _selectedFood == null ? null : _saveSelectedFood,
                ),
        ],
      ),
    );
  }

  Widget _buildNaturalLanguageTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        DropdownButton<MealType>(
          value: _mealType,
          items: MealType.values
              .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
              .toList(),
          onChanged: (m) => setState(() => _mealType = m ?? _mealType),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _naturalLanguageController,
          decoration: const InputDecoration(labelText: 'Describe what you ate'),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: _parseNaturalLanguage, child: const Text('Parse')),
        _buildParsedItemsReview(),
      ],
    );
  }

  Widget _buildPhotoTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        DropdownButton<MealType>(
          value: _mealType,
          items: MealType.values
              .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
              .toList(),
          onChanged: (m) => setState(() => _mealType = m ?? _mealType),
        ),
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
