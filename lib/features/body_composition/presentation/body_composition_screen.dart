import 'package:flutter/material.dart';
import '../../../core/calculations/body_composition_calculator.dart';
import '../../../core/calculations/nutrition_goal_calculator.dart' show Sex;
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/data/user_profile_repository.dart';
import '../data/body_composition_repository.dart';
import '../domain/body_composition_estimate.dart';
import '../domain/body_measurement.dart';

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
  final _chestController = TextEditingController();
  final _thighController = TextEditingController();
  final _upperArmController = TextEditingController();
  final _forearmController = TextEditingController();

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
    _chestController.dispose();
    _thighController.dispose();
    _upperArmController.dispose();
    _forearmController.dispose();
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
    final chest = _parse(_chestController);
    final thigh = _parse(_thighController);
    final upperArm = _parse(_upperArmController);
    final forearm = _parse(_forearmController);

    final now = DateTime.now();
    final method = _method.trim().isEmpty ? null : _method.trim();

    final measurements = <BodyMeasurement>[
      BodyMeasurement(metric: BodyMetric.weight, value: weight, unit: 'kg', measuredAt: now, createdAt: now, method: method),
      BodyMeasurement(metric: BodyMetric.waist, value: waist, unit: 'cm', measuredAt: now, createdAt: now, method: method),
      BodyMeasurement(metric: BodyMetric.neck, value: neck, unit: 'cm', measuredAt: now, createdAt: now, method: method),
      if (hip != null) BodyMeasurement(metric: BodyMetric.hip, value: hip, unit: 'cm', measuredAt: now, createdAt: now, method: method),
      if (chest != null) BodyMeasurement(metric: BodyMetric.chest, value: chest, unit: 'cm', measuredAt: now, createdAt: now, method: method),
      if (thigh != null) BodyMeasurement(metric: BodyMetric.thigh, value: thigh, unit: 'cm', measuredAt: now, createdAt: now, method: method),
      if (upperArm != null)
        BodyMeasurement(metric: BodyMetric.upperArm, value: upperArm, unit: 'cm', measuredAt: now, createdAt: now, method: method),
      if (forearm != null)
        BodyMeasurement(metric: BodyMetric.forearm, value: forearm, unit: 'cm', measuredAt: now, createdAt: now, method: method),
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
      _chestController.clear();
      _thighController.clear();
      _upperArmController.clear();
      _forearmController.clear();
    });

    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Body composition')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('New check-in', style: textTheme.headlineMedium),
                        const SizedBox(height: 8),
                        Text(
                          'Body-fat and lean-body-mass values are estimates, not medical measurements.',
                          style: textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('weightField'),
                          controller: _weightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Weight (kg)'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('waistField'),
                          controller: _waistController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Waist (cm)'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('neckField'),
                          controller: _neckController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Neck (cm)'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('hipField'),
                          controller: _hipController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: widget.profile.sex == Sex.female
                                ? 'Hip (cm) — required for your estimate'
                                : 'Hip (cm, optional)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('chestField'),
                          controller: _chestController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Chest (cm, optional)'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('thighField'),
                          controller: _thighController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Thigh (cm, optional)'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('upperArmField'),
                          controller: _upperArmController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Upper arm (cm, optional)'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('forearmField'),
                          controller: _forearmController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Forearm (cm, optional)'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: const Key('methodDropdown'),
                          initialValue: _method,
                          decoration: const InputDecoration(labelText: 'Measurement method'),
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
                        const SizedBox(height: 24),
                        PrimaryButton(label: 'Save check-in', onPressed: _save),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('History', style: textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Weight', style: textTheme.bodyLarge),
                        const SizedBox(height: 8),
                        if (_weightHistory.isEmpty)
                          Text('No weight check-ins yet.', style: textTheme.bodyMedium)
                        else
                          for (final measurement in _weightHistory.reversed)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '${measurement.measuredAt.toIso8601String().split('T').first}: '
                                '${measurement.value.toStringAsFixed(1)} ${measurement.unit}',
                                style: textTheme.bodyMedium,
                              ),
                            ),
                        const SizedBox(height: 16),
                        Text('Body fat', style: textTheme.bodyLarge),
                        const SizedBox(height: 8),
                        if (_estimateHistory.isEmpty)
                          Text('No body-fat estimates yet.', style: textTheme.bodyMedium)
                        else
                          for (final estimate in _estimateHistory.reversed)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '${estimate.calculatedAt.toIso8601String().split('T').first}: '
                                '${estimate.bodyFatPercent.toStringAsFixed(1)}%',
                                style: textTheme.bodyMedium?.copyWith(color: AppColors.accentGreen),
                              ),
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
