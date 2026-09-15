import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_label.dart';
import '../data/coach_service.dart';
import '../domain/coach_event.dart';
import '../domain/coach_recommendation.dart';

/// Lists AI coach recommendations with accept/reject actions, and a simple
/// audit log view of what `handleCommand` actually did with each decision.
///
/// This is intentionally not a chat UI (out of scope for Phase 7, per the
/// plan) — just a list/detail view plus an audit trail, sufficient for
/// personal use. Glass-UI rebuild per handoff screen 15: every number/word
/// here (summary, rationale, status, event trail) is real data from
/// [CoachService] — nothing on this screen is fabricated.
class CoachRecommendationsScreen extends StatefulWidget {
  const CoachRecommendationsScreen({super.key, required this.uid, required this.service});

  final String uid;
  final CoachService service;

  @override
  State<CoachRecommendationsScreen> createState() => _CoachRecommendationsScreenState();
}

class _CoachRecommendationsScreenState extends State<CoachRecommendationsScreen> {
  List<CoachRecommendation> _recommendations = [];
  List<CoachEvent> _events = [];
  bool _loading = true;
  bool _showAuditLog = false;
  bool _generating = false;
  bool _summarizing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final recommendations = await widget.service.listRecommendations(widget.uid);
      final events = await widget.service.listEvents(widget.uid);
      if (!mounted) return;
      setState(() {
        _recommendations = recommendations;
        _events = events;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load coach data: $error';
        _loading = false;
      });
    }
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      await widget.service.generateRecommendation();
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not generate a recommendation: $error');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _summarize() async {
    setState(() => _summarizing = true);
    try {
      final summary = await widget.service.summarizeProgress();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Your progress'),
          content: Text(summary),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not summarize progress: $error');
    } finally {
      if (mounted) setState(() => _summarizing = false);
    }
  }

  Future<void> _decide(CoachRecommendation recommendation, {required bool approve}) async {
    try {
      await widget.service.submitDecision(recommendation.id, approve: approve);
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not submit decision: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'AI Coach',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 28),
                            ),
                          ),
                          _GlassToggle(
                            key: const Key('coachAuditToggle'),
                            label: _showAuditLog ? 'Recommendations' : 'Audit log',
                            onTap: () => setState(() => _showAuditLog = !_showAuditLog),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_error != null) ...[
                        Text(_error!, style: const TextStyle(color: AppColors.error)),
                        const SizedBox(height: 16),
                      ],
                      if (!_showAuditLog) ...[
                        PrimaryButton(
                          label: _generating ? 'Generating...' : 'Get a new recommendation',
                          onPressed: _generating ? null : _generate,
                        ),
                        const SizedBox(height: 12),
                        _GlassToggle(
                          fullWidth: true,
                          label: _summarizing ? 'Summarizing...' : 'Summarize my progress',
                          onTap: _summarizing ? null : _summarize,
                        ),
                        const SizedBox(height: 24),
                        SectionLabel('Recommendations'),
                        const SizedBox(height: 12),
                        if (_recommendations.isEmpty)
                          const Text(
                            'No recommendations yet.',
                            style: TextStyle(color: AppColors.textSecondary),
                          )
                        else
                          ..._recommendations.map(
                            (recommendation) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _RecommendationCard(
                                recommendation: recommendation,
                                onApprove: () => _decide(recommendation, approve: true),
                                onReject: () => _decide(recommendation, approve: false),
                              ),
                            ),
                          ),
                      ] else ...[
                        SectionLabel('Audit log'),
                        const SizedBox(height: 12),
                        if (_events.isEmpty)
                          const Text(
                            'No coach activity yet.',
                            style: TextStyle(color: AppColors.textSecondary),
                          )
                        else
                          ..._events.map(
                            (event) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _EventCard(event: event),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.recommendation,
    required this.onApprove,
    required this.onReject,
  });

  final CoachRecommendation recommendation;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  Color get _statusColor => switch (recommendation.status) {
        RecommendationStatus.pending => AppColors.warningYellow,
        RecommendationStatus.accepted => AppColors.accentGreen,
        RecommendationStatus.rejected => AppColors.error,
      };

  @override
  Widget build(BuildContext context) {
    final isPending = recommendation.status == RecommendationStatus.pending;
    return GlassCard(
      glowColor: _statusColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recommendation.summary,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          // Rationale is shown in full — never truncated — the reasoning is
          // the entire point of an explainable recommendation.
          Text(
            recommendation.rationale,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
          ),
          if (recommendation.proposedCommand != null) ...[
            const SizedBox(height: 12),
            Text(
              'Proposed: ${recommendation.proposedCommand!.type}',
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
            ),
            Text(
              recommendation.proposedCommand!.raw.toString(),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Status: ${recommendation.status.name}',
            style: TextStyle(color: _statusColor, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          if (isPending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _PillButton(
                    label: 'Accept',
                    filled: true,
                    color: AppColors.accentGreen,
                    onTap: onApprove,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PillButton(
                    label: 'Reject',
                    filled: false,
                    color: AppColors.textPrimary,
                    onTap: onReject,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final CoachEvent event;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      glowColor: AppColors.accentViolet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Outcome: ${event.outcome}',
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text('Decision: ${event.decision}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 4),
          Text(event.reason, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            event.createdAt.toIso8601String(),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// A stadium-shaped glass pill used for the header's "Audit log" toggle and
/// the "Summarize my progress" secondary action. Not filled with the accent
/// gradient like [PrimaryButton] — this is a lighter-weight secondary
/// action per the handoff's header toggle.
class _GlassToggle extends StatelessWidget {
  const _GlassToggle({super.key, required this.label, required this.onTap, this.fullWidth = false});

  final String label;
  final VoidCallback? onTap;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.6,
      child: Material(
        color: AppColors.glassFill,
        shape: const StadiumBorder(side: BorderSide(color: AppColors.glassStroke)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            width: fullWidth ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small stadium pill for the Accept/Reject row — [filled] gives the solid
/// accent-coloured Accept treatment, unfilled gives the glass outline
/// Reject treatment, per the handoff.
class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.filled, required this.color, required this.onTap});

  final String label;
  final bool filled;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? color.withValues(alpha: 0.85) : AppColors.glassFill,
      shape: StadiumBorder(side: BorderSide(color: filled ? color : AppColors.glassStroke)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: filled ? AppColors.background : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
