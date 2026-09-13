import 'package:flutter/material.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/coach_service.dart';
import '../domain/coach_event.dart';
import '../domain/coach_recommendation.dart';

/// Lists AI coach recommendations with accept/reject actions, and a simple
/// audit log view of what `handleCommand` actually did with each decision.
///
/// This is intentionally not a chat UI (out of scope for Phase 7, per the
/// plan) — just a list/detail view plus an audit trail, sufficient for
/// personal use.
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
      appBar: AppBar(
        title: const Text('AI Coach'),
        actions: [
          IconButton(
            icon: Icon(_showAuditLog ? Icons.lightbulb_outline : Icons.history),
            tooltip: _showAuditLog ? 'Recommendations' : 'Audit log',
            onPressed: () => setState(() => _showAuditLog = !_showAuditLog),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 16),
                    ],
                    if (!_showAuditLog) ...[
                      PrimaryButton(
                        label: _generating ? 'Generating...' : 'Get a new recommendation',
                        onPressed: _generating ? null : _generate,
                      ),
                      const SizedBox(height: 16),
                      if (_recommendations.isEmpty)
                        const Text('No recommendations yet.')
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
                      if (_events.isEmpty)
                        const Text('No coach activity yet.')
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

  @override
  Widget build(BuildContext context) {
    final isPending = recommendation.status == RecommendationStatus.pending;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(recommendation.summary, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(recommendation.rationale),
          if (recommendation.proposedCommand != null) ...[
            const SizedBox(height: 12),
            Text(
              'Proposed: ${recommendation.proposedCommand!.type}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(recommendation.proposedCommand!.raw.toString()),
          ],
          const SizedBox(height: 12),
          Text('Status: ${recommendation.status.name}'),
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: PrimaryButton(label: 'Accept', onPressed: onApprove)),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(onPressed: onReject, child: const Text('Reject')),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Outcome: ${event.outcome}', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Decision: ${event.decision}'),
          const SizedBox(height: 4),
          Text(event.reason),
          const SizedBox(height: 4),
          Text(event.createdAt.toIso8601String(), style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
