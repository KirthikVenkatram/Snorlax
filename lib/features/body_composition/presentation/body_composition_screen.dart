import 'package:flutter/material.dart';
import '../../../core/calculations/body_composition_calculator.dart';
import '../../../core/calculations/nutrition_goal_calculator.dart' show Sex;
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/glass_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/progress_chart.dart';
import '../../../core/widgets/section_label.dart';
import '../../auth/data/user_profile_repository.dart';
import '../data/body_composition_repository.dart';
import '../domain/body_composition_estimate.dart';
import '../domain/body_measurement.dart';

/// Body composition — per handoff Screen 18 (`/body-composition`): a
/// "New check-in" glass card (weight/waist/neck, plus hip when the
/// calculator needs it) and two history charts sourced from the same
/// `BodyCompositionRepository` data Trends' weight chart already reads.
///
/// Only the four fields [BodyCompositionCalculator.estimate] actually
/// consumes are shown — the repo's [BodyMetric] enum still has room for
/// chest/thigh/upper-arm/forearm readings, but nothing computes an
/// estimate from them today, and the mockup's check-in card is a 2x2 grid
/// of exactly these four fields (see docs/superpowers/ISSUES.md, Group H).
class BodyCompositionScreen extends StatefulWidget {
  const BodyCompositionScreen({
    super.key,
    required this.uid,
    required this.profile,
    required this.repository,
    required this.onChanged,
  });

  final String uid;
  final UserProfile profile;
  final BodyCompositionRepository repository;
  final VoidCallback onChanged;

  @override
  State<BodyCompositionScreen> createState() => _BodyCompositionScreenState();
}

class _BodyCompositionScreenState extends State<BodyCompositionScreen> {
  final _weightController = TextEditingController();
  final _waistController = TextEditingController();
  final _neckController = TextEditingController();
  final _hipController = TextEditingController();

  String _method = 'manual';
  List<BodyMeasurement> _weightHistory = [];
  List<BodyCompositionEstimate> _estimateHistory = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _waistController.dispose();
    _neckController.dispose();
    _hipController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final weightHistory = await widget.repository.listMeasurements(widget.uid, BodyMetric.weight);
    final estimateHistory = await widget.repository.listEstimates(widget.uid);
    if (!mounted) return;
    setState(() {
      _weightHistory = weightHistory;
      _estimateHistory = estimateHistory;
      _loading = false;
    });
  }

  double? _parse(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  void _save() {
    final weight = _parse(_weightController);
    final waist = _parse(_waistController);
    final neck = _parse(_neckController);
    if (weight == null || waist == null || neck == null) return;

    final hip = _parse(_hipController);

    final now = DateTime.now();
    final method = _method.trim().isEmpty ? null : _method.trim();

    final measurements = <BodyMeasurement>[
      BodyMeasurement(metric: BodyMetric.weight, value: weight, unit: 'kg', measuredAt: now, createdAt: now, method: method),
      BodyMeasurement(metric: BodyMetric.waist, value: waist, unit: 'cm', measuredAt: now, createdAt: now, method: method),
      BodyMeasurement(metric: BodyMetric.neck, value: neck, unit: 'cm', measuredAt: now, createdAt: now, method: method),
      if (hip != null) BodyMeasurement(metric: BodyMetric.hip, value: hip, unit: 'cm', measuredAt: now, createdAt: now, method: method),
    ];

    // Deliberately not awaited: Firestore's offline persistence updates the
    // local cache immediately but the returned Future doesn't resolve until
    // the server acks, which never happens offline — awaiting it here would
    // leave this screen spinning indefinitely with no connectivity.
    for (final measurement in measurements) {
      widget.repository
          .recordMeasurement(widget.uid, measurement)
          .then((_) {}, onError: (Object error) => debugPrint('Failed to save measurement: $error'));
    }

    // Only attempt an estimate when the calculator's required inputs are
    // satisfiable: sex/height come from the profile, and a female estimate
    // additionally requires a supplied hip circumference. If the user
    // hasn't supplied enough circumference data, skip the estimate and just
    // save the raw measurements above — don't let a missing-input
    // ArgumentError from the calculator crash the save flow.
    final canAttemptEstimate = widget.profile.sex == Sex.male || hip != null;
    BodyCompositionEstimate? estimate;
    if (canAttemptEstimate) {
      try {
        estimate = BodyCompositionCalculator.estimate(
          sex: widget.profile.sex,
          heightCm: widget.profile.heightCm,
          weightKg: weight,
          waistCm: waist,
          neckCm: neck,
          hipCm: hip,
          calculatedAt: now,
        );
      } on ArgumentError catch (error) {
        debugPrint('Not enough/valid data for a body-composition estimate: $error');
        estimate = null;
      }
    }

    if (estimate != null) {
      widget.repository
          .recordEstimate(widget.uid, estimate)
          .then((_) {}, onError: (Object error) => debugPrint('Failed to save estimate: $error'));
    }

    setState(() {
      _weightHistory = [
        BodyMeasurement(metric: BodyMetric.weight, value: weight, unit: 'kg', measuredAt: now, createdAt: now, method: method),
        ..._weightHistory,
      ];
      if (estimate != null) {
        _estimateHistory = [estimate, ..._estimateHistory];
      }
      _weightController.clear();
      _waistController.clear();
      _neckController.clear();
      _hipController.clear();
    });

    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Body composition'), backgroundColor: Colors.transparent),
      body: AmbientBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    GlassCard(
                      hero: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('New check-in', style: textTheme.headlineMedium?.copyWith(fontSize: 20)),
                          const SizedBox(height: 8),
                          Text(
                            'Body-fat and lean-body-mass values are estimates, not medical measurements.',
                            style: textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: GlassTextField(
                                  fieldKey: const Key('weightField'),
                                  label: 'Weight (kg)',
                                  controller: _weightController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GlassTextField(
                                  fieldKey: const Key('waistField'),
                                  label: 'Waist (cm)',
                                  controller: _waistController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: GlassTextField(
                                  fieldKey: const Key('neckField'),
                                  label: 'Neck (cm)',
                                  controller: _neckController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GlassTextField(
                                  fieldKey: const Key('hipField'),
                                  label: widget.profile.sex == Sex.female ? 'Hip (cm)' : 'Hip (cm, optional)',
                                  controller: _hipController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            key: const Key('methodDropdown'),
                            initialValue: _method,
                            dropdownColor: AppColors.surface,
                            style: const TextStyle(color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: 'Measurement method',
                              labelStyle: const TextStyle(color: AppColors.textSecondary),
                              filled: true,
                              fillColor: AppColors.glassFill,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppColors.glassStroke),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'manual', child: Text('manual')),
                              DropdownMenuItem(value: 'tape', child: Text('tape')),
                              DropdownMenuItem(value: 'scale', child: Text('scale')),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _method = value);
                            },
                          ),
                          const SizedBox(height: 20),
                          PrimaryButton(label: 'Save check-in', onPressed: _save),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionLabel('Weight history', color: AppColors.accentGreen),
                          const SizedBox(height: 12),
                          if (_weightHistory.isEmpty)
                            Text('No weight check-ins yet.', style: textTheme.bodyMedium)
                          else
                            SizedBox(
                              height: 160,
                              child: ProgressChart(
                                points: [
                                  for (final m in _weightHistory)
                                    ProgressPoint(date: m.measuredAt, value: m.value),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassCard(
                      glowColor: AppColors.accentViolet,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionLabel('Body fat history', color: AppColors.accentViolet),
                          const SizedBox(height: 12),
                          if (_estimateHistory.isEmpty)
                            Text('No body-fat estimates yet.', style: textTheme.bodyMedium)
                          else
                            SizedBox(
                              height: 160,
                              child: ProgressChart(
                                points: [
                                  for (final e in _estimateHistory)
                                    ProgressPoint(date: e.calculatedAt, value: e.bodyFatPercent),
                                ],
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
}
