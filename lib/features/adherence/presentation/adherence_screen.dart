import 'package:flutter/material.dart';
import '../../../core/calculations/adherence_calculator.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/adherence_repository.dart';
import '../domain/adherence_summary.dart';

class AdherenceScreen extends StatefulWidget {
  const AdherenceScreen({super.key, required this.uid, required this.repository});

  final String uid;
  final AdherenceRepository repository;

  @override
  State<AdherenceScreen> createState() => _AdherenceScreenState();
}

class _AdherenceScreenState extends State<AdherenceScreen> {
  DailyAdherenceSummary? _daily;
  WeeklyAdherenceSummary? _weekly;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final daily = await widget.repository.computeAndCacheDaily(widget.uid, now);
    final weekly = await widget.repository.computeAndCacheWeekly(widget.uid, now);
    if (!mounted) return;
    setState(() {
      _daily = daily;
      _weekly = weekly;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Adherence')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Today', style: textTheme.headlineMedium),
                        const SizedBox(height: 8),
                        Text(
                          _daily?.overallScore != null
                              ? '${((_daily!.overallScore!) * 100).round()}%'
                              : 'No score yet',
                          style: textTheme.displaySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AdherenceCalculator.supportiveSummary(_daily?.overallScore),
                          key: const Key('dailySupportiveSummary'),
                          style: textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        if (_daily != null)
                          for (final component in AdherenceComponent.values)
                            _ComponentRow(
                              component: component,
                              score: _daily!.componentScores[component],
                              excluded: _daily!.excludedComponents.contains(component),
                            ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('This week', style: textTheme.headlineMedium),
                        const SizedBox(height: 8),
                        Text(
                          _weekly?.overallScore != null
                              ? '${((_weekly!.overallScore!) * 100).round()}%'
                              : 'No score yet',
                          style: textTheme.displaySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AdherenceCalculator.supportiveSummary(_weekly?.overallScore),
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(label: 'Refresh', onPressed: _load),
                ],
              ),
      ),
    );
  }
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({required this.component, required this.score, required this.excluded});

  final AdherenceComponent component;
  final double? score;
  final bool excluded;

  String get _label => switch (component) {
        AdherenceComponent.nutrition => 'Nutrition',
        AdherenceComponent.training => 'Training',
        AdherenceComponent.habits => 'Habits',
        AdherenceComponent.recovery => 'Recovery',
      };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(_label, style: textTheme.bodyMedium)),
          Text(
            excluded ? 'Not counted today' : '${((score ?? 0) * 100).round()}%',
            style: textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
