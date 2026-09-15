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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _ClosePill(onTap: () => Navigator.of(context).pop()),
                      _TorchButton(
                        torchOn: _torchOn,
                        onTap: () async {
                          await _controller.toggleTorch();
                          if (mounted) setState(() => _torchOn = !_torchOn);
                        },
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 260,
                  height: 260,
                  child: CustomPaint(painter: _ViewfinderPainter()),
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

/// Top-left "Close" pill — text only, per Screen 8's glass-pill header.
class _ClosePill extends StatelessWidget {
  const _ClosePill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text('Close', style: TextStyle(color: Colors.white, fontSize: 14)),
        ),
      ),
    );
  }
}

/// Top-right round icon-only torch toggle, per Screen 8's header.
class _TorchButton extends StatelessWidget {
  const _TorchButton({required this.torchOn, required this.onTap});

  final bool torchOn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            torchOn ? Icons.flash_on : Icons.flash_off,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}

/// Corner-bracket barcode viewfinder: a faint dashed rounded-square outline
/// with four glowing neon corner brackets, per Screen 8 of the handoff —
/// deliberately not a plain solid-border box.
class _ViewfinderPainter extends CustomPainter {
  static const _radius = 24.0;
  static const _bracketLength = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(_radius));

    final dashedPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    _drawDashedRRect(canvas, rrect, dashedPaint);

    final bracketPaint = Paint()
      ..color = AppColors.accentGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final glowPaint = Paint()
      ..color = AppColors.accentGreen.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    for (final paint in [glowPaint, bracketPaint]) {
      // Top-left
      canvas.drawLine(const Offset(0, _bracketLength), Offset(0, _radius), paint);
      canvas.drawArc(Rect.fromCircle(center: const Offset(_radius, _radius), radius: _radius),
          3.14159, 1.5708, false, paint);
      canvas.drawLine(const Offset(_radius, 0), const Offset(_bracketLength, 0), paint);

      // Top-right
      canvas.drawLine(Offset(size.width - _bracketLength, 0), Offset(size.width - _radius, 0), paint);
      canvas.drawArc(
          Rect.fromCircle(center: Offset(size.width - _radius, _radius), radius: _radius),
          -1.5708, 1.5708, false, paint);
      canvas.drawLine(
          Offset(size.width, _radius), Offset(size.width, _bracketLength), paint);

      // Bottom-left
      canvas.drawLine(
          Offset(0, size.height - _bracketLength), Offset(0, size.height - _radius), paint);
      canvas.drawArc(
          Rect.fromCircle(center: Offset(_radius, size.height - _radius), radius: _radius),
          1.5708, 1.5708, false, paint);
      canvas.drawLine(Offset(_radius, size.height), Offset(_bracketLength, size.height), paint);

      // Bottom-right
      canvas.drawLine(Offset(size.width, size.height - _bracketLength),
          Offset(size.width, size.height - _radius), paint);
      canvas.drawArc(
          Rect.fromCircle(
              center: Offset(size.width - _radius, size.height - _radius), radius: _radius),
          0,
          1.5708,
          false,
          paint);
      canvas.drawLine(Offset(size.width - _radius, size.height),
          Offset(size.width - _bracketLength, size.height), paint);
    }
  }

  void _drawDashedRRect(Canvas canvas, RRect rrect, Paint paint) {
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dashWidth = 6.0, dashGap = 5.0;
      while (distance < metric.length) {
        final next = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
