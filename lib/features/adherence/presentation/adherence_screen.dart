import 'package:flutter/material.dart';
import '../../../core/calculations/adherence_calculator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../data/adherence_repository.dart';
import '../domain/adherence_summary.dart';

/// Adherence screen — handoff Screen 14: a hero glass card for "Today" and
/// a second for "This week", each showing the blended percentage plus the
/// four component rows. The scoring itself (`AdherenceCalculator`,
/// `AdherenceRepository`) is untouched — this is a restyle of the shell
/// only.
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Adherence'), backgroundColor: Colors.transparent),
      body: AmbientBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _ScoreCard(
                        kicker: 'TODAY',
                        score: _daily?.overallScore,
                        summary: AdherenceCalculator.supportiveSummary(_daily?.overallScore),
                        summaryKey: const Key('dailySupportiveSummary'),
                        componentScores: _daily?.componentScores ?? const {},
                        excludedComponents: _daily?.excludedComponents ?? const {},
                        hero: true,
                      ),
                      const SizedBox(height: 16),
                      _ScoreCard(
                        kicker: 'THIS WEEK',
                        score: _weekly?.overallScore,
                        summary: AdherenceCalculator.supportiveSummary(_weekly?.overallScore),
                        summaryKey: const Key('weeklySupportiveSummary'),
                        componentScores: const {},
                        excludedComponents: const {},
                        hero: false,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.kicker,
    required this.score,
    required this.summary,
    required this.summaryKey,
    required this.componentScores,
    required this.excludedComponents,
    required this.hero,
  });

  final String kicker;
  final double? score;
  final String summary;
  final Key summaryKey;
  final Map<AdherenceComponent, double> componentScores;
  final Set<AdherenceComponent> excludedComponents;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      hero: hero,
      glowColor: AppColors.accentGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kicker, style: AppTypography.mono(color: AppColors.accentGreen, letterSpacing: 1.6)),
          const SizedBox(height: 10),
          Text(
            score != null ? '${(score! * 100).round()}%' : '—',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: AppColors.accentGreen,
              letterSpacing: -0.02,
              shadows: [
                Shadow(color: AppColors.accentGreen.withValues(alpha: 0.55), blurRadius: 22),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(summary, key: summaryKey, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          if (componentScores.isNotEmpty || excludedComponents.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            for (final component in AdherenceComponent.values)
              _ComponentRow(
                component: component,
                score: componentScores[component],
                excluded: excludedComponents.contains(component),
              ),
          ],
        ],
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(_label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          ),
          Text(
            excluded ? 'Not counted today' : '${((score ?? 0) * 100).round()}%',
            style: TextStyle(
              color: excluded ? AppColors.textSecondary : AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
