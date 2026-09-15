import 'package:flutter/material.dart';
import '../../../core/calculations/nutrition_goal_calculator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/glass_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/segmented_pill.dart';
import '../data/user_profile_repository.dart';

/// 3-step onboarding wizard per the glass-UI handoff (screen 02): a name +
/// age/sex step, a weight/height/activity step, and a goal + live-computed
/// targets summary step. Public API (`uid`/`profileRepository`/`onComplete`)
/// is unchanged from the previous implementation — `app_router.dart`
/// constructs this the same way it always has.
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
  static const _stepCount = 3;

  int _step = 0;
  bool _saving = false;
  String? _stepError;

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  Sex _sex = Sex.male;
  ActivityLevel _activityLevel = ActivityLevel.moderate;
  Goal _goal = Goal.maintain;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  double? get _weightKg => double.tryParse(_weightController.text.trim());
  double? get _heightCm => double.tryParse(_heightController.text.trim());
  int? get _age => int.tryParse(_ageController.text.trim());

  NutritionTargets? get _targets {
    final weightKg = _weightKg;
    final heightCm = _heightCm;
    final age = _age;
    if (weightKg == null || heightCm == null || age == null) return null;
    return NutritionGoalCalculator.calculate(
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      sex: _sex,
      activityLevel: _activityLevel,
      goal: _goal,
    );
  }

  void _onFieldChanged(String _) => setState(() {});

  Future<void> _next() async {
    setState(() => _stepError = null);

    if (_step == 0) {
      if (_age == null) {
        setState(() => _stepError = 'Enter a valid age.');
        return;
      }
    } else if (_step == 1) {
      if (_weightKg == null || _heightCm == null) {
        setState(() => _stepError = 'Enter a valid weight and height.');
        return;
      }
    } else {
      await _submit();
      return;
    }

    setState(() => _step += 1);
  }

  void _back() {
    if (_step == 0) return;
    setState(() {
      _step -= 1;
      _stepError = null;
    });
  }

  Future<void> _submit() async {
    final targets = _targets;
    if (targets == null) {
      setState(() {
        _step = 1;
        _stepError = 'Enter a valid weight and height.';
      });
      return;
    }

    setState(() => _saving = true);

    final profile = UserProfile(
      age: _age!,
      weightKg: _weightKg!,
      heightCm: _heightCm!,
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
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: _ProgressPills(step: _step, count: _stepCount),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STEP ${_step + 1} OF $_stepCount',
                        style: const TextStyle(
                          color: AppColors.accentGreen,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _stepTitle,
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 34),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _stepSubtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: AppColors.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      GlassCard(child: _buildStepContent()),
                      if (_stepError != null) ...[
                        const SizedBox(height: 12),
                        Text(_stepError!, style: const TextStyle(color: AppColors.error)),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    if (_step > 0) ...[
                      _BackPill(onTap: _saving ? null : _back),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: _saving
                          ? const Center(child: CircularProgressIndicator())
                          : PrimaryButton(
                              label: _step == _stepCount - 1 ? 'Start tracking' : 'Continue',
                              onPressed: _next,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _stepTitle => switch (_step) {
        0 => "Who's training?",
        1 => 'Your numbers',
        _ => 'Pick a direction',
      };

  String get _stepSubtitle => switch (_step) {
        0 => 'Two taps and a name. Nothing leaves your account.',
        1 => 'Used to work out your daily calorie and macro targets.',
        _ => 'You can change this any time — targets update instantly.',
      };

  Widget _buildStepContent() {
    return switch (_step) {
      0 => _StepWho(
          nameController: _nameController,
          ageController: _ageController,
          sex: _sex,
          onSexChanged: (v) => setState(() => _sex = v),
          onFieldChanged: _onFieldChanged,
        ),
      1 => _StepNumbers(
          weightController: _weightController,
          heightController: _heightController,
          activityLevel: _activityLevel,
          onActivityChanged: (v) => setState(() => _activityLevel = v),
          onFieldChanged: _onFieldChanged,
        ),
      _ => _StepGoal(
          goal: _goal,
          onGoalChanged: (v) => setState(() => _goal = v),
          targets: _targets,
        ),
    };
  }
}

class _ProgressPills extends StatelessWidget {
  const _ProgressPills({required this.step, required this.count});

  final int step;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: i <= step ? AppColors.accentGreen : AppColors.glassFill,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BackPill extends StatelessWidget {
  const _BackPill({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.glassFill,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.glassStroke)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Text(
            'Back',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
      ),
    );
  }
}

class _StepWho extends StatelessWidget {
  const _StepWho({
    required this.nameController,
    required this.ageController,
    required this.sex,
    required this.onSexChanged,
    required this.onFieldChanged,
  });

  final TextEditingController nameController;
  final TextEditingController ageController;
  final Sex sex;
  final ValueChanged<Sex> onSexChanged;
  final ValueChanged<String> onFieldChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassTextField(
          key: const Key('onboardingNameField'),
          label: 'Name',
          controller: nameController,
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: GlassTextField(
                key: const Key('onboardingAgeField'),
                label: 'Age',
                controller: ageController,
                keyboardType: TextInputType.number,
                onChanged: onFieldChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sex', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  SegmentedPill<Sex>(
                    options: Sex.values,
                    value: sex,
                    labelBuilder: (s) => s == Sex.male ? 'Male' : 'Female',
                    onChanged: onSexChanged,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StepNumbers extends StatelessWidget {
  const _StepNumbers({
    required this.weightController,
    required this.heightController,
    required this.activityLevel,
    required this.onActivityChanged,
    required this.onFieldChanged,
  });

  final TextEditingController weightController;
  final TextEditingController heightController;
  final ActivityLevel activityLevel;
  final ValueChanged<ActivityLevel> onActivityChanged;
  final ValueChanged<String> onFieldChanged;

  static const _activityLabels = {
    ActivityLevel.sedentary: 'Sedentary',
    ActivityLevel.light: 'Light',
    ActivityLevel.moderate: 'Moderate',
    ActivityLevel.active: 'Active',
    ActivityLevel.veryActive: 'Very active',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: GlassTextField(
                key: const Key('onboardingWeightField'),
                label: 'Weight (kg)',
                controller: weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: onFieldChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GlassTextField(
                key: const Key('onboardingHeightField'),
                label: 'Height (cm)',
                controller: heightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: onFieldChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Activity level', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        for (final level in ActivityLevel.values) ...[
          _ActivityPill(
            key: Key('onboardingActivity_${level.name}'),
            label: _activityLabels[level]!,
            selected: level == activityLevel,
            onTap: () => onActivityChanged(level),
          ),
          if (level != ActivityLevel.values.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ActivityPill extends StatelessWidget {
  const _ActivityPill({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentGreen.withValues(alpha: 0.18) : AppColors.glassFill,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.accentGreen.withValues(alpha: 0.45) : AppColors.glassStroke,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.accentGreen : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

class _StepGoal extends StatelessWidget {
  const _StepGoal({required this.goal, required this.onGoalChanged, required this.targets});

  final Goal goal;
  final ValueChanged<Goal> onGoalChanged;
  final NutritionTargets? targets;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedPill<Goal>(
          options: Goal.values,
          value: goal,
          labelBuilder: (g) => switch (g) {
            Goal.lose => 'Lose fat',
            Goal.maintain => 'Maintain',
            Goal.gain => 'Build',
          },
          subLabelBuilder: (g) => switch (g) {
            Goal.lose => '-500kcal',
            Goal.maintain => '±0kcal',
            Goal.gain => '+500kcal',
          },
          onChanged: onGoalChanged,
        ),
        const SizedBox(height: 20),
        GlassCard(
          hero: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DAILY TARGETS',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12, letterSpacing: 1.2),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    targets != null ? '${targets!.calories}' : '—',
                    key: const Key('onboardingTargetCalories'),
                    style: const TextStyle(
                      color: AppColors.accentGreen,
                      fontSize: 58,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(color: AppColors.accentGreen, blurRadius: 24)],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text('kcal', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _MacroTile(
                      label: 'PROTEIN',
                      value: targets != null ? '${targets!.proteinGrams.round()}g' : '—',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MacroTile(
                      label: 'CARBS',
                      value: targets != null ? '${targets!.carbsGrams.round()}g' : '—',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MacroTile(
                      label: 'FAT',
                      value: targets != null ? '${targets!.fatGrams.round()}g' : '—',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Mifflin-St Jeor, scaled by activity, adjusted for your goal. '
                'Editable any time.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MacroTile extends StatelessWidget {
  const _MacroTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, letterSpacing: 1.0)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
