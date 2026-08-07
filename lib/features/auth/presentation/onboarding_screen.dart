// lib/features/auth/presentation/onboarding_screen.dart
import 'package:flutter/material.dart';
import '../../../core/calculations/nutrition_goal_calculator.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../data/user_profile_repository.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.uid,
    required this.profileRepository,
    required this.onComplete,
  });

  final String uid;
  final UserProfileRepository profileRepository;
  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  Sex _sex = Sex.male;
  ActivityLevel _activityLevel = ActivityLevel.moderate;
  Goal _goal = Goal.maintain;
  bool _saving = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final age = int.parse(_ageController.text);
    final weightKg = double.parse(_weightController.text);
    final heightCm = double.parse(_heightController.text);

    final targets = NutritionGoalCalculator.calculate(
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      sex: _sex,
      activityLevel: _activityLevel,
      goal: _goal,
    );

    final profile = UserProfile(
      age: age,
      weightKg: weightKg,
      heightCm: heightCm,
      sex: _sex,
      activityLevel: _activityLevel,
      goal: _goal,
      targets: targets,
    );

    await widget.profileRepository.saveProfile(widget.uid, profile);

    if (!mounted) return;
    setState(() => _saving = false);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Set up your profile', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Age'),
                    validator: (v) => (v == null || int.tryParse(v) == null) ? 'Enter a valid age' : null,
                  ),
                  TextFormField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Weight (kg)'),
                    validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter a valid weight' : null,
                  ),
                  TextFormField(
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Height (cm)'),
                    validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter a valid height' : null,
                  ),
                  DropdownButtonFormField<Sex>(
                    initialValue: _sex,
                    decoration: const InputDecoration(labelText: 'Sex'),
                    items: Sex.values
                        .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _sex = v!),
                  ),
                  DropdownButtonFormField<ActivityLevel>(
                    initialValue: _activityLevel,
                    decoration: const InputDecoration(labelText: 'Activity level'),
                    items: ActivityLevel.values
                        .map((a) => DropdownMenuItem(value: a, child: Text(a.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _activityLevel = v!),
                  ),
                  DropdownButtonFormField<Goal>(
                    initialValue: _goal,
                    decoration: const InputDecoration(labelText: 'Goal'),
                    items: Goal.values
                        .map((g) => DropdownMenuItem(value: g, child: Text(g.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _goal = v!),
                  ),
                  const SizedBox(height: 24),
                  _saving
                      ? const Center(child: CircularProgressIndicator())
                      : GradientButton(label: 'Continue', onPressed: _submit),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
