import 'package:flutter/material.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/data/user_profile_repository.dart';
import '../data/nutrition_repository.dart';
import '../domain/food_entry.dart';

class NutritionGoalsScreen extends StatefulWidget {
  const NutritionGoalsScreen({
    super.key,
    required this.uid,
    required this.nutritionRepository,
    required this.onSaved,
    this.userProfileRepository,
  });

  final String uid;
  final NutritionRepository nutritionRepository;
  final VoidCallback onSaved;

  /// Optional. When the user has not saved their own nutrition goals yet,
  /// the fields are pre-filled from the targets computed during onboarding
  /// (`users/{uid}.targets`). Saved goals always win over these.
  final UserProfileRepository? userProfileRepository;

  @override
  State<NutritionGoalsScreen> createState() => _NutritionGoalsScreenState();
}

class _NutritionGoalsScreenState extends State<NutritionGoalsScreen> {
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadInitialValues();
  }

  Future<void> _loadInitialValues() async {
    final goals = await widget.nutritionRepository.getGoals(widget.uid);
    if (!mounted) return;
    if (goals != null) {
      _caloriesController.text = goals.dailyCalories.toStringAsFixed(0);
      _proteinController.text = goals.proteinG.toStringAsFixed(0);
      _carbsController.text = goals.carbsG.toStringAsFixed(0);
      _fatController.text = goals.fatG.toStringAsFixed(0);
      return;
    }

    // Nothing saved yet — fall back to the targets computed at onboarding.
    // Note the field-name mismatch between NutritionGoals and
    // NutritionTargets; these are mapped one by one, not interchangeable.
    final repository = widget.userProfileRepository;
    if (repository == null) return;
    UserProfile? profile;
    try {
      profile = await repository.getProfile(widget.uid);
    } catch (error) {
      debugPrint('Could not load profile targets: $error');
      return;
    }
    if (!mounted || profile == null) return;
    final targets = profile.targets;
    _caloriesController.text = targets.calories.toString();
    _proteinController.text = targets.proteinGrams.toStringAsFixed(0);
    _carbsController.text = targets.carbsGrams.toStringAsFixed(0);
    _fatController.text = targets.fatGrams.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final calories = double.tryParse(_caloriesController.text);
    final protein = double.tryParse(_proteinController.text);
    final carbs = double.tryParse(_carbsController.text);
    final fat = double.tryParse(_fatController.text);
    if (calories == null || protein == null || carbs == null || fat == null) return;

    setState(() => _saving = true);
    // Fire-and-handle-errors, not awaited: Firestore's offline persistence
    // updates the local cache immediately but the returned Future doesn't
    // resolve until the server acks, which never happens offline — awaiting
    // it here would leave this screen spinning indefinitely with no
    // connectivity.
    widget.nutritionRepository
        .setGoals(
          widget.uid,
          NutritionGoals(dailyCalories: calories, proteinG: protein, carbsG: carbs, fatG: fat),
        )
        .then((_) {}, onError: (Object error) => debugPrint('Failed to save goals: $error'));
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nutrition goals')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const Key('caloriesField'),
                  controller: _caloriesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Daily calories'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('proteinField'),
                  controller: _proteinController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Protein (g)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('carbsField'),
                  controller: _carbsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Carbs (g)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('fatField'),
                  controller: _fatController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Fat (g)'),
                ),
                const SizedBox(height: 24),
                _saving
                    ? const Center(child: CircularProgressIndicator())
                    : PrimaryButton(label: 'Save goals', onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
