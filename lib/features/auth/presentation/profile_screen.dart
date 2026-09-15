import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/calculations/adherence_calculator.dart';
import '../../../core/calculations/nutrition_goal_calculator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/glass_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_label.dart';
import '../../../core/widgets/segmented_pill.dart';
import '../../adherence/data/adherence_repository.dart';
import '../data/auth_repository.dart';
import '../data/user_profile_repository.dart';

/// The glass-UI Profile screen (handoff screens 12/13): name + summary
/// line, a live daily-targets hero card, a weight/height/goal editor that
/// recomputes targets on the fly, a settings list, and sign-out.
///
/// Folds in the *real* sign-out and adherence-weight-editing logic that
/// used to live only in [SettingsScreen] rather than duplicating a second
/// settings surface — `/settings` itself keeps working for anything still
/// linking to it, but this is now the primary Account destination.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.uid,
    required this.email,
    required this.profileRepository,
    required this.adherenceRepository,
    required this.authRepository,
    this.displayName,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final UserProfileRepository profileRepository;
  final AdherenceRepository adherenceRepository;
  final AuthRepository authRepository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loadingProfile = true;
  UserProfile? _profile;

  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  Goal? _goal;
  bool _savingProfile = false;
  String? _profileSaveMessage;

  bool _adherenceExpanded = false;
  bool _loadingWeights = true;
  bool _savingWeights = false;
  String? _weightsSaveMessage;
  final _adherenceFormKey = GlobalKey<FormState>();
  final _adherenceNutritionController = TextEditingController();
  final _adherenceTrainingController = TextEditingController();
  final _adherenceHabitsController = TextEditingController();
  final _adherenceRecoveryController = TextEditingController();

  bool _signingOut = false;

  static const _activityLabels = {
    ActivityLevel.sedentary: 'sedentary',
    ActivityLevel.light: 'light',
    ActivityLevel.moderate: 'moderate',
    ActivityLevel.active: 'active',
    ActivityLevel.veryActive: 'very active',
  };

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadWeights();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _adherenceNutritionController.dispose();
    _adherenceTrainingController.dispose();
    _adherenceHabitsController.dispose();
    _adherenceRecoveryController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await widget.profileRepository.getProfile(widget.uid);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _goal = profile?.goal;
      _weightController.text = profile != null ? _trimZeros(profile.weightKg) : '';
      _heightController.text = profile != null ? _trimZeros(profile.heightCm) : '';
      _loadingProfile = false;
    });
  }

  Future<void> _loadWeights() async {
    final weights = await widget.adherenceRepository.getWeights(widget.uid);
    if (!mounted) return;
    setState(() {
      _adherenceNutritionController.text = _trimZeros(weights.nutrition);
      _adherenceTrainingController.text = _trimZeros(weights.training);
      _adherenceHabitsController.text = _trimZeros(weights.habits);
      _adherenceRecoveryController.text = _trimZeros(weights.recovery);
      _loadingWeights = false;
    });
  }

  static String _trimZeros(double value) {
    var text = value.toStringAsFixed(2);
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
    return text.isEmpty ? '0' : text;
  }

  double? get _weightKg => double.tryParse(_weightController.text.trim());
  double? get _heightCm => double.tryParse(_heightController.text.trim());

  NutritionTargets? get _liveTargets {
    final profile = _profile;
    final weightKg = _weightKg;
    final heightCm = _heightCm;
    final goal = _goal;
    if (profile == null || weightKg == null || heightCm == null || goal == null) return null;
    return NutritionGoalCalculator.calculate(
      weightKg: weightKg,
      heightCm: heightCm,
      age: profile.age,
      sex: profile.sex,
      activityLevel: profile.activityLevel,
      goal: goal,
    );
  }

  Future<void> _saveProfile() async {
    final profile = _profile;
    final targets = _liveTargets;
    if (profile == null || targets == null) return;

    setState(() {
      _savingProfile = true;
      _profileSaveMessage = null;
    });

    final updated = UserProfile(
      age: profile.age,
      weightKg: _weightKg!,
      heightCm: _heightCm!,
      sex: profile.sex,
      activityLevel: profile.activityLevel,
      goal: _goal!,
      targets: targets,
    );

    await widget.profileRepository.saveProfile(widget.uid, updated);

    if (!mounted) return;
    setState(() {
      _profile = updated;
      _savingProfile = false;
      _profileSaveMessage = 'Saved.';
    });
  }

  String? _validateAdherenceWeight(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final parsed = double.tryParse(value.trim());
    if (parsed == null) return 'Enter a number';
    if (parsed < 0) return 'Must be non-negative';
    return null;
  }

  Future<void> _saveAdherenceWeights() async {
    setState(() => _weightsSaveMessage = null);
    if (!(_adherenceFormKey.currentState?.validate() ?? false)) return;

    final nutrition = double.parse(_adherenceNutritionController.text.trim());
    final training = double.parse(_adherenceTrainingController.text.trim());
    final habits = double.parse(_adherenceHabitsController.text.trim());
    final recovery = double.parse(_adherenceRecoveryController.text.trim());

    if (nutrition + training + habits + recovery <= 0) {
      setState(() => _weightsSaveMessage = 'At least one weight must be greater than zero.');
      return;
    }

    setState(() => _savingWeights = true);
    try {
      await widget.adherenceRepository.setWeights(
        widget.uid,
        AdherenceWeights(nutrition: nutrition, training: training, habits: habits, recovery: recovery),
      );
      if (!mounted) return;
      setState(() {
        _savingWeights = false;
        _weightsSaveMessage = 'Saved.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _savingWeights = false;
        _weightsSaveMessage = 'Could not save: $e';
      });
    }
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await widget.authRepository.signOut();
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        child: SafeArea(
          child: _loadingProfile
              ? const Center(child: CircularProgressIndicator())
              : _profile == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'We could not find your profile. Please complete onboarding first.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                      children: [
                        Text(
                          widget.displayName ?? 'Signed in',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 28),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_profile!.age} · ${_profile!.weightKg.round()} kg · '
                          '${_profile!.heightCm.round()} cm · ${_activityLabels[_profile!.activityLevel]}',
                          key: const Key('profileSummaryLine'),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                        const SizedBox(height: 20),
                        _buildTargetsCard(),
                        const SizedBox(height: 16),
                        _buildEditorCard(),
                        const SizedBox(height: 24),
                        SectionLabel('Settings'),
                        const SizedBox(height: 8),
                        _buildSettingsList(context),
                        const SizedBox(height: 24),
                        _GlassPill(
                          key: const Key('profileReplayOnboardingButton'),
                          label: 'Replay onboarding',
                          onTap: () => GoRouter.of(context).push('/onboarding'),
                        ),
                        const SizedBox(height: 12),
                        _GlassPill(
                          key: const Key('profileSignOutButton'),
                          label: _signingOut ? 'Signing out...' : 'Sign out',
                          color: AppColors.error,
                          onTap: _signingOut ? null : _signOut,
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildTargetsCard() {
    final targets = _liveTargets ?? _profile!.targets;
    return GlassCard(
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
                '${targets.calories}',
                key: const Key('profileTargetCalories'),
                style: const TextStyle(
                  color: AppColors.accentGreen,
                  fontSize: 50,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: AppColors.accentGreen, blurRadius: 24)],
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('kcal', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _MacroTile(label: 'PROTEIN', value: '${targets.proteinGrams.round()}g')),
              const SizedBox(width: 10),
              Expanded(child: _MacroTile(label: 'CARBS', value: '${targets.carbsGrams.round()}g')),
              const SizedBox(width: 10),
              Expanded(child: _MacroTile(label: 'FAT', value: '${targets.fatGrams.round()}g')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditorCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GlassTextField(
                  key: const Key('profileWeightField'),
                  label: 'Weight (kg)',
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GlassTextField(
                  key: const Key('profileHeightField'),
                  label: 'Height (cm)',
                  controller: _heightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Goal', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          SegmentedPill<Goal>(
            options: Goal.values,
            value: _goal ?? Goal.maintain,
            labelBuilder: (g) => switch (g) {
              Goal.lose => 'Lose fat',
              Goal.maintain => 'Maintain',
              Goal.gain => 'Build',
            },
            onChanged: (g) => setState(() => _goal = g),
          ),
          const SizedBox(height: 12),
          const Text(
            'Targets recalculate the moment you change anything here.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (_profileSaveMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _profileSaveMessage!,
                key: const Key('profileSaveMessage'),
                style: const TextStyle(color: AppColors.accentGreen),
              ),
            ),
          _savingProfile
              ? const Center(child: CircularProgressIndicator())
              : PrimaryButton(label: 'Save', onPressed: _saveProfile),
        ],
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.surfaceGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.glassStroke),
        ),
        child: Column(
          children: [
            const _StaticSettingsRow(label: 'Reminders'),
            const Divider(height: 1, indent: 16, color: Colors.white12),
            const _StaticSettingsRow(label: 'Units'),
            const Divider(height: 1, indent: 16, color: Colors.white12),
            const _StaticSettingsRow(label: 'Connected'),
            const Divider(height: 1, indent: 16, color: Colors.white12),
            const _StaticSettingsRow(label: 'Export data'),
            const Divider(height: 1, indent: 16, color: Colors.white12),
            _AdherenceWeightsSection(
              expanded: _adherenceExpanded,
              onToggle: () => setState(() => _adherenceExpanded = !_adherenceExpanded),
              loading: _loadingWeights,
              formKey: _adherenceFormKey,
              nutritionController: _adherenceNutritionController,
              trainingController: _adherenceTrainingController,
              habitsController: _adherenceHabitsController,
              recoveryController: _adherenceRecoveryController,
              validator: _validateAdherenceWeight,
              saving: _savingWeights,
              message: _weightsSaveMessage,
              onSave: _saveAdherenceWeights,
            ),
          ],
        ),
      ),
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

class _StaticSettingsRow extends StatelessWidget {
  const _StaticSettingsRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15))),
          const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

/// The adherence-weight editor from `SettingsScreen`, folded in here as a
/// collapsed section instead of a duplicated settings surface.
class _AdherenceWeightsSection extends StatelessWidget {
  const _AdherenceWeightsSection({
    required this.expanded,
    required this.onToggle,
    required this.loading,
    required this.formKey,
    required this.nutritionController,
    required this.trainingController,
    required this.habitsController,
    required this.recoveryController,
    required this.validator,
    required this.saving,
    required this.message,
    required this.onSave,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final bool loading;
  final GlobalKey<FormState> formKey;
  final TextEditingController nutritionController;
  final TextEditingController trainingController;
  final TextEditingController habitsController;
  final TextEditingController recoveryController;
  final String? Function(String?) validator;
  final bool saving;
  final String? message;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          key: const Key('profileAdherenceWeightsToggle'),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Adherence weights', style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How much each area counts toward your daily/weekly adherence score.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        GlassTextField(
                          fieldKey: const Key('profileAdherenceNutritionField'),
                          label: 'Nutrition',
                          controller: nutritionController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: validator,
                        ),
                        const SizedBox(height: 10),
                        GlassTextField(
                          fieldKey: const Key('profileAdherenceTrainingField'),
                          label: 'Training',
                          controller: trainingController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: validator,
                        ),
                        const SizedBox(height: 10),
                        GlassTextField(
                          fieldKey: const Key('profileAdherenceHabitsField'),
                          label: 'Habits',
                          controller: habitsController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: validator,
                        ),
                        const SizedBox(height: 10),
                        GlassTextField(
                          fieldKey: const Key('profileAdherenceRecoveryField'),
                          label: 'Recovery',
                          controller: recoveryController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: validator,
                        ),
                        const SizedBox(height: 12),
                        if (message != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              message!,
                              key: const Key('profileWeightsSaveMessage'),
                              style: const TextStyle(color: AppColors.accentGreen),
                            ),
                          ),
                        saving
                            ? const Center(child: CircularProgressIndicator())
                            : PrimaryButton(label: 'Save weights', onPressed: onSave),
                      ],
                    ),
                  ),
          ),
      ],
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({super.key, required this.label, required this.onTap, this.color = AppColors.textPrimary});

  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tinted = color != AppColors.textPrimary;
    return Material(
      color: tinted ? color.withValues(alpha: 0.12) : AppColors.glassFill,
      shape: StadiumBorder(side: BorderSide(color: tinted ? color.withValues(alpha: 0.4) : AppColors.glassStroke)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
      ),
    );
  }
}
