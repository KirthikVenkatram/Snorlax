import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/calculations/adherence_calculator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../adherence/data/adherence_repository.dart';
import '../../auth/data/auth_repository.dart';

/// Settings/profile screen: adherence-weight configuration, profile + sign
/// out, app version, and a single consolidated non-medical-advice
/// disclaimer covering nutrition/readiness/body-composition estimates.
///
/// Nothing here is celebratory, so it follows the everyday `GlassCard`/
/// `PrimaryButton`/`AppColors` conventions used across the rest of the app
/// rather than any of the gradient/celebration widgets.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.uid,
    required this.email,
    required this.adherenceRepository,
    required this.authRepository,
  });

  final String uid;
  final String? email;
  final AdherenceRepository adherenceRepository;
  final AuthRepository authRepository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nutritionController = TextEditingController();
  final _trainingController = TextEditingController();
  final _habitsController = TextEditingController();
  final _recoveryController = TextEditingController();

  bool _loadingWeights = true;
  bool _savingWeights = false;
  bool _signingOut = false;
  String? _saveError;
  String? _saveSuccess;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadWeights();
    _loadVersion();
  }

  Future<void> _loadWeights() async {
    final weights = await widget.adherenceRepository.getWeights(widget.uid);
    if (!mounted) return;
    setState(() {
      _nutritionController.text = _formatWeight(weights.nutrition);
      _trainingController.text = _formatWeight(weights.training);
      _habitsController.text = _formatWeight(weights.habits);
      _recoveryController.text = _formatWeight(weights.recovery);
      _loadingWeights = false;
    });
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _version = 'v${info.version} (${info.buildNumber})');
    } catch (_) {
      // Version display is cosmetic only — never let a lookup failure
      // affect the rest of the settings screen.
      if (!mounted) return;
      setState(() => _version = 'unknown');
    }
  }

  String _formatWeight(double value) {
    // Trim trailing zeros (0.40 -> 0.4) so the field doesn't look odd
    // when a user just wants to nudge one value.
    var text = value.toStringAsFixed(2);
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
    return text.isEmpty ? '0' : text;
  }

  String? _validateWeight(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final parsed = double.tryParse(value.trim());
    if (parsed == null) return 'Enter a number';
    if (parsed < 0) return 'Must be non-negative';
    return null;
  }

  Future<void> _saveWeights() async {
    setState(() {
      _saveError = null;
      _saveSuccess = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final nutrition = double.parse(_nutritionController.text.trim());
    final training = double.parse(_trainingController.text.trim());
    final habits = double.parse(_habitsController.text.trim());
    final recovery = double.parse(_recoveryController.text.trim());

    if (nutrition + training + habits + recovery <= 0) {
      setState(() => _saveError = 'At least one weight must be greater than zero.');
      return;
    }

    setState(() => _savingWeights = true);
    try {
      await widget.adherenceRepository.setWeights(
        widget.uid,
        AdherenceWeights(
          nutrition: nutrition,
          training: training,
          habits: habits,
          recovery: recovery,
        ),
      );
      if (!mounted) return;
      setState(() {
        _savingWeights = false;
        _saveSuccess = 'Saved.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _savingWeights = false;
        _saveError = 'Could not save: $e';
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
  void dispose() {
    _nutritionController.dispose();
    _trainingController.dispose();
    _habitsController.dispose();
    _recoveryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Profile', style: textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    widget.email ?? 'Signed in',
                    key: const Key('settingsEmailText'),
                    style: textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: _signingOut ? 'Signing out...' : 'Sign out',
                    onPressed: _signingOut ? null : _signOut,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Adherence weights', style: textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(
                      'How much each area counts toward your daily/weekly adherence '
                      'score. Weights don\'t need to sum to any particular total — '
                      'days where a component doesn\'t apply are excluded and the '
                      'rest are renormalized automatically.',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    if (_loadingWeights)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      _WeightField(
                        label: 'Nutrition',
                        fieldKey: const Key('weightNutritionField'),
                        controller: _nutritionController,
                        validator: _validateWeight,
                      ),
                      const SizedBox(height: 12),
                      _WeightField(
                        label: 'Training',
                        fieldKey: const Key('weightTrainingField'),
                        controller: _trainingController,
                        validator: _validateWeight,
                      ),
                      const SizedBox(height: 12),
                      _WeightField(
                        label: 'Habits',
                        fieldKey: const Key('weightHabitsField'),
                        controller: _habitsController,
                        validator: _validateWeight,
                      ),
                      const SizedBox(height: 12),
                      _WeightField(
                        label: 'Recovery',
                        fieldKey: const Key('weightRecoveryField'),
                        controller: _recoveryController,
                        validator: _validateWeight,
                      ),
                      const SizedBox(height: 16),
                      if (_saveError != null)
                        Text(
                          _saveError!,
                          key: const Key('weightsSaveError'),
                          style: const TextStyle(color: AppColors.error),
                        ),
                      if (_saveSuccess != null)
                        Text(
                          _saveSuccess!,
                          key: const Key('weightsSaveSuccess'),
                          style: const TextStyle(color: AppColors.accentGreen),
                        ),
                      const SizedBox(height: 8),
                      PrimaryButton(
                        label: _savingWeights ? 'Saving...' : 'Save weights',
                        onPressed: _savingWeights ? null : _saveWeights,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('About', style: textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    _version.isEmpty ? 'Loading version...' : _version,
                    key: const Key('settingsVersionText'),
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Not medical advice', style: textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Nutrition targets, body-fat/lean-mass estimates, readiness '
                    'scores, and adherence scores throughout this app are '
                    'self-reported, deterministic estimates for personal tracking '
                    'only. None of them are medical advice, a diagnosis, or a '
                    'medically validated assessment of any kind — consult a '
                    'qualified professional for medical or nutritional guidance.',
                    key: const Key('settingsDisclaimerText'),
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightField extends StatelessWidget {
  const _WeightField({
    required this.label,
    required this.fieldKey,
    required this.controller,
    required this.validator,
  });

  final String label;
  final Key fieldKey;
  final TextEditingController controller;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.textSecondary),
        ),
      ),
      validator: validator,
    );
  }
}
