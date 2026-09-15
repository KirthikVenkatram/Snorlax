import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/food_search_service.dart';
import '../data/nutrition_repository.dart';
import '../data/open_food_facts_client.dart';
import '../data/recipe_repository.dart';
import '../domain/food_entry.dart';
import '../domain/scanned_food.dart';
import 'recipe_builder_screen.dart';

/// Full-screen barcode capture per the design handoff Screen 8. Reachable
/// only from Log food's "Scan" pill. Camera permission denial and a
/// not-found lookup both fall back to the same "build it from ingredients"
/// path — never a dead end.
class ScanFoodScreen extends StatefulWidget {
  const ScanFoodScreen({
    super.key,
    required this.uid,
    required this.nutritionRepository,
    required this.searchService,
    required this.recipeRepository,
    required this.date,
    required this.onLogged,
  });

  final String uid;
  final NutritionRepository nutritionRepository;
  final FoodSearchService searchService;
  final RecipeRepository recipeRepository;
  final DateTime date;
  final VoidCallback onLogged;

  @override
  State<ScanFoodScreen> createState() => _ScanFoodScreenState();
}

class _ScanFoodScreenState extends State<ScanFoodScreen> {
  final _controller = MobileScannerController();
  final _client = OpenFoodFactsClient();
  bool _looking = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_looking) return;
    final barcode = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (barcode == null) return;

    setState(() => _looking = true);
    await _controller.stop();
    final food = await _client.lookupBarcode(barcode);
    if (!mounted) return;

    if (food == null) {
      setState(() => _looking = false);
      await _controller.start();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't find that barcode. Try again, or build it yourself.")),
      );
      return;
    }

    final logged = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MatchSheet(
        food: food,
        onAdd: (mealType, grams) async {
          final scale = grams / 100;
          await widget.nutritionRepository.logFood(
            uid: widget.uid,
            date: widget.date,
            mealType: mealType,
            foodName: food.name,
            quantityGrams: grams,
            calories: food.caloriesPer100g * scale,
            proteinG: food.proteinPer100g * scale,
            carbsG: food.carbsPer100g * scale,
            fatG: food.fatPer100g * scale,
            source: FoodSource.openFoodFactsScanned,
          );
        },
      ),
    );

    if (!mounted) return;
    if (logged == true) {
      widget.onLogged();
      Navigator.of(context).pop();
      return;
    }
    setState(() => _looking = false);
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Container(color: Colors.black.withValues(alpha: 0.35)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _ScanIconButton(
                        icon: Icons.close,
                        label: 'Close',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      _ScanIconButton(
                        icon: _torchOn ? Icons.flash_on : Icons.flash_off,
                        label: 'Torch',
                        onTap: () async {
                          await _controller.toggleTorch();
                          if (mounted) setState(() => _torchOn = !_torchOn);
                        },
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.accentGreen, width: 3),
                    boxShadow: [
                      BoxShadow(color: AppColors.accentGreen.withValues(alpha: 0.5), blurRadius: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Camera preview — hold the barcode inside the frame',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 16),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      _looking ? 'Looking that up…' : 'Looking for a barcode…',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RecipeBuilderScreen(
                            uid: widget.uid,
                            date: widget.date,
                            searchService: widget.searchService,
                            recipeRepository: widget.recipeRepository,
                            nutritionRepository: widget.nutritionRepository,
                            onSaved: widget.onLogged,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'No barcode? Build it from ingredients',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanIconButton extends StatelessWidget {
  const _ScanIconButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchSheet extends StatefulWidget {
  const _MatchSheet({required this.food, required this.onAdd});

  final ScannedFood food;
  final Future<void> Function(MealType mealType, double grams) onAdd;

  @override
  State<_MatchSheet> createState() => _MatchSheetState();
}

class _MatchSheetState extends State<_MatchSheet> {
  double _grams = 100;
  MealType _mealType = MealType.snack;
  bool _adding = false;

  @override
  Widget build(BuildContext context) {
    final scale = _grams / 100;
    final kcal = (widget.food.caloriesPer100g * scale).round();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.92),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(widget.food.name, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20)),
                const SizedBox(height: 4),
                Text(
                  'Open Food Facts · ${widget.food.barcode}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('$kcal', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 40)),
                    const SizedBox(width: 8),
                    const Padding(padding: EdgeInsets.only(top: 12), child: Text('kcal')),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _grams <= 10 ? null : () => setState(() => _grams -= 10),
                    ),
                    Text('${_grams.round()}g'),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setState(() => _grams += 10),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final meal in MealType.values)
                      ChoiceChip(
                        label: Text(meal.name),
                        selected: _mealType == meal,
                        onSelected: (_) => setState(() => _mealType = meal),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Scan again'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(
                        label: _adding ? 'Adding…' : 'Add to log',
                        onPressed: _adding
                            ? null
                            : () async {
                                setState(() => _adding = true);
                                await widget.onAdd(_mealType, _grams);
                                if (context.mounted) Navigator.of(context).pop(true);
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
