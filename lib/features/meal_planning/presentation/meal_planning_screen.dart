import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/calculations/meal_plan_calculator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../coach/data/coach_service.dart';
import '../data/budget_repository.dart';
import '../data/meal_plan_repository.dart';
import '../data/meal_template_repository.dart';
import '../domain/budget_settings.dart';
import '../domain/meal_plan.dart';
import '../domain/meal_template.dart';
import '../domain/price_snapshot.dart';

/// Budget settings, reusable meal templates, and saved/proposed meal plans
/// in one screen — following the same "one screen, no chat UI, list +
/// simple forms" convention as `ReadinessCheckInScreen`/
/// `CoachRecommendationsScreen` for a fast-track feature of this scope.
///
/// AI-proposed plans land here as `mealPlans` documents too (written only
/// via the coach `handleCommand` approve flow, never directly by this
/// screen) — this view does not distinguish source in its list beyond the
/// small "AI proposed" label, since both paths went through the same
/// deterministic calculator.
class MealPlanningScreen extends StatefulWidget {
  const MealPlanningScreen({
    super.key,
    required this.uid,
    required this.budgetRepository,
    required this.templateRepository,
    required this.planRepository,
    required this.coachService,
  });

  final String uid;
  final BudgetRepository budgetRepository;
  final MealTemplateRepository templateRepository;
  final MealPlanRepository planRepository;

  /// Used only by the "Ask coach to propose a plan" action, which calls
  /// `CoachService.generateMealPlanRecommendation` and then hands the user
  /// off to `/coach` to review/accept/reject it — this screen never writes
  /// an AI-proposed plan directly.
  final CoachService coachService;

  @override
  State<MealPlanningScreen> createState() => _MealPlanningScreenState();
}

class _MealPlanningScreenState extends State<MealPlanningScreen> {
  BudgetSettings? _budget;
  List<MealTemplate> _templates = [];
  List<MealPlan> _plans = [];
  bool _loading = true;
  bool _askingCoach = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final budget = await widget.budgetRepository.get(widget.uid);
      final templates = await widget.templateRepository.list(widget.uid);
      final plans = await widget.planRepository.list(widget.uid);
      if (!mounted) return;
      setState(() {
        _budget = budget;
        _templates = templates;
        _plans = plans;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load meal planning data: $error';
        _loading = false;
      });
    }
  }

  Future<void> _editBudget() async {
    final result = await showDialog<BudgetSettings>(
      context: context,
      builder: (context) => _BudgetEditorDialog(initial: _budget),
    );
    if (result == null) return;
    await widget.budgetRepository.save(widget.uid, result);
    await _load();
  }

  Future<void> _addTemplate() async {
    final result = await showDialog<MealTemplate>(
      context: context,
      builder: (context) => const _TemplateEditorDialog(),
    );
    if (result == null) return;
    await widget.templateRepository.create(widget.uid, result);
    await _load();
  }

  Future<void> _buildPlan() async {
    if (_templates.isEmpty) {
      setState(() => _error = 'Add at least one meal template before building a plan.');
      return;
    }
    final result = await showDialog<_PlanDraft>(
      context: context,
      builder: (context) => _PlanBuilderDialog(templates: _templates),
    );
    if (result == null) return;
    await widget.planRepository.createFromTemplates(
      uid: widget.uid,
      name: result.name,
      periodType: result.periodType,
      lines: result.lines,
      currency: _budget?.currency ?? 'USD',
    );
    await _load();
  }

  /// Calls `generateMealPlanRecommendation` and, on success, hands off to
  /// `/coach` where the resulting proposal is reviewed and accepted/
  /// rejected — this screen never persists an AI-proposed plan itself; the
  /// coach `handleCommand` approve flow is the only path that does.
  Future<void> _askCoach() async {
    setState(() => _askingCoach = true);
    try {
      await widget.coachService.generateMealPlanRecommendation();
      if (!mounted) return;
      GoRouter.of(context).push('/coach');
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not ask the coach for a meal plan: $error');
    } finally {
      if (mounted) setState(() => _askingCoach = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meal planning')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 16),
                    ],
                    _BudgetCard(budget: _budget, onEdit: _editBudget),
                    const SizedBox(height: 16),
                    _TemplatesCard(templates: _templates, onAdd: _addTemplate),
                    const SizedBox(height: 16),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Meal plans', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          const Text(
                            'Build a plan from your templates, or review one the AI coach proposed '
                            '(only saved here after you approve it in the coach screen).',
                          ),
                          const SizedBox(height: 12),
                          PrimaryButton(label: 'Build a plan', onPressed: _buildPlan),
                          const SizedBox(height: 8),
                          PrimaryButton(
                            label: 'Ask coach to propose a plan',
                            onPressed: _askingCoach ? null : _askCoach,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_plans.isEmpty)
                      const Text('No meal plans yet.')
                    else
                      ..._plans.map(
                        (plan) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _PlanCard(plan: plan),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.budget, required this.onEdit});

  final BudgetSettings? budget;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final budget = this.budget;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Budget', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (budget == null)
            const Text('No budget set yet — proposals will still show cost, just without a ceiling to check against.')
          else ...[
            Text('Currency: ${budget.currency}'),
            Text('Daily limit: ${budget.dailyLimit?.toStringAsFixed(2) ?? 'not set'}'),
            Text('Weekly limit: ${budget.weeklyLimit?.toStringAsFixed(2) ?? 'not set'}'),
            Text('Monthly limit: ${budget.monthlyLimit?.toStringAsFixed(2) ?? 'not set'}'),
          ],
          const SizedBox(height: 12),
          PrimaryButton(label: budget == null ? 'Set a budget' : 'Edit budget', onPressed: onEdit),
        ],
      ),
    );
  }
}

class _TemplatesCard extends StatelessWidget {
  const _TemplatesCard({required this.templates, required this.onAdd});

  final List<MealTemplate> templates;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Meal templates', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (templates.isEmpty)
            const Text('No templates yet.')
          else
            ...templates.map(
              (template) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${template.name} — ${_costLabel(template.costPerServing, template.currency, template.costSource)}, '
                  '${template.caloriesPerServing.toStringAsFixed(0)} kcal, '
                  '${template.proteinGPerServing.toStringAsFixed(0)}g protein',
                ),
              ),
            ),
          const SizedBox(height: 12),
          PrimaryButton(label: 'Add a template', onPressed: onAdd),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});

  final MealPlan plan;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(plan.name, style: Theme.of(context).textTheme.titleMedium)),
              if (plan.source == MealPlanSource.aiProposal)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text('AI proposed', style: TextStyle(color: AppColors.accentViolet, fontSize: 12)),
                ),
            ],
          ),
          Text('${plan.periodType.name} plan'),
          const SizedBox(height: 8),
          Text(
            plan.totalCost != null
                ? 'Total cost: ${plan.totalCost!.toStringAsFixed(2)} ${plan.currency}'
                : 'Total cost: unavailable (one or more items are unpriced)',
          ),
          Text(
            plan.periodType == MealPlanPeriodType.daily
                ? 'Weekly projection: ${_projected(plan, MealPlanPeriodType.weekly)}'
                : 'Daily equivalent: ${_projected(plan, MealPlanPeriodType.daily)}',
          ),
          Text('Monthly projection: ${_monthlyProjection(plan)}'),
          if (plan.totalCalories != null) Text('Total calories: ${plan.totalCalories!.toStringAsFixed(0)} kcal'),
          if (plan.totalProteinG != null) Text('Total protein: ${plan.totalProteinG!.toStringAsFixed(0)} g'),
          if (plan.proteinPerCurrencyUnit != null)
            Text('Protein per ${plan.currency}: ${plan.proteinPerCurrencyUnit!.toStringAsFixed(1)} g'),
          const SizedBox(height: 8),
          ...plan.items.map(
            (item) => Text(
              '${item.templateName} x${item.servings.toStringAsFixed(item.servings.truncateToDouble() == item.servings ? 0 : 1)}'
              ' — ${item.lineCost != null ? '${item.lineCost!.toStringAsFixed(2)} ${plan.currency}' : 'unpriced'}',
            ),
          ),
        ],
      ),
    );
  }

  String _projected(MealPlan plan, MealPlanPeriodType target) {
    final daily = MealPlanCalculator.dailyCostFromPlanTotal(plan.totalCost, plan.periodType);
    final projected = MealPlanCalculator.projectCost(daily, target);
    return projected != null ? '${projected.toStringAsFixed(2)} ${plan.currency}' : 'unavailable';
  }

  String _monthlyProjection(MealPlan plan) {
    final daily = MealPlanCalculator.dailyCostFromPlanTotal(plan.totalCost, plan.periodType);
    final projected = MealPlanCalculator.projectMonthlyCost(daily);
    return projected != null ? '${projected.toStringAsFixed(2)} ${plan.currency}' : 'unavailable';
  }
}

String _costLabel(double? cost, String currency, PriceSource source) {
  if (cost == null) {
    return source == PriceSource.unavailable ? 'price unavailable (live)' : 'no price on file';
  }
  final sourceLabel = switch (source) {
    PriceSource.manual => 'manual',
    PriceSource.live => 'live',
    PriceSource.estimated => 'estimated',
    PriceSource.unavailable => 'unavailable',
  };
  return '${cost.toStringAsFixed(2)} $currency ($sourceLabel)';
}

class _BudgetEditorDialog extends StatefulWidget {
  const _BudgetEditorDialog({required this.initial});

  final BudgetSettings? initial;

  @override
  State<_BudgetEditorDialog> createState() => _BudgetEditorDialogState();
}

class _BudgetEditorDialogState extends State<_BudgetEditorDialog> {
  late final TextEditingController _currency =
      TextEditingController(text: widget.initial?.currency ?? 'USD');
  late final TextEditingController _daily =
      TextEditingController(text: widget.initial?.dailyLimit?.toString() ?? '');
  late final TextEditingController _weekly =
      TextEditingController(text: widget.initial?.weeklyLimit?.toString() ?? '');
  late final TextEditingController _monthly =
      TextEditingController(text: widget.initial?.monthlyLimit?.toString() ?? '');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Budget settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _currency, decoration: const InputDecoration(labelText: 'Currency (e.g. USD)')),
            TextField(
              controller: _daily,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Daily limit'),
            ),
            TextField(
              controller: _weekly,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Weekly limit (optional)'),
            ),
            TextField(
              controller: _monthly,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Monthly limit (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(
              BudgetSettings(
                currency: _currency.text.trim().isEmpty ? 'USD' : _currency.text.trim(),
                dailyLimit: double.tryParse(_daily.text.trim()),
                weeklyLimit: double.tryParse(_weekly.text.trim()),
                monthlyLimit: double.tryParse(_monthly.text.trim()),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _TemplateEditorDialog extends StatefulWidget {
  const _TemplateEditorDialog();

  @override
  State<_TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<_TemplateEditorDialog> {
  final _name = TextEditingController();
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _cost = TextEditingController();
  final _currency = TextEditingController(text: 'USD');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New meal template'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(
              controller: _calories,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Calories per serving'),
            ),
            TextField(
              controller: _protein,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Protein (g) per serving'),
            ),
            TextField(
              controller: _carbs,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Carbs (g) per serving'),
            ),
            TextField(
              controller: _fat,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Fat (g) per serving'),
            ),
            TextField(
              controller: _cost,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Cost per serving (leave blank if unknown)'),
            ),
            TextField(controller: _currency, decoration: const InputDecoration(labelText: 'Currency')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) return;
            final cost = double.tryParse(_cost.text.trim());
            Navigator.of(context).pop(
              MealTemplate(
                id: '',
                name: _name.text.trim(),
                servings: 1,
                caloriesPerServing: double.tryParse(_calories.text.trim()) ?? 0,
                proteinGPerServing: double.tryParse(_protein.text.trim()) ?? 0,
                carbsGPerServing: double.tryParse(_carbs.text.trim()) ?? 0,
                fatGPerServing: double.tryParse(_fat.text.trim()) ?? 0,
                costPerServing: cost,
                currency: _currency.text.trim().isEmpty ? 'USD' : _currency.text.trim(),
                costSource: cost != null ? PriceSource.manual : PriceSource.unavailable,
                costTimestamp: DateTime.now(),
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _PlanDraft {
  const _PlanDraft({required this.name, required this.periodType, required this.lines});

  final String name;
  final MealPlanPeriodType periodType;
  final List<MealPlanLineInput> lines;
}

class _PlanBuilderDialog extends StatefulWidget {
  const _PlanBuilderDialog({required this.templates});

  final List<MealTemplate> templates;

  @override
  State<_PlanBuilderDialog> createState() => _PlanBuilderDialogState();
}

class _PlanBuilderDialogState extends State<_PlanBuilderDialog> {
  final _name = TextEditingController(text: 'My plan');
  MealPlanPeriodType _periodType = MealPlanPeriodType.daily;
  final Map<String, int> _servingsByTemplateId = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Build a plan'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Plan name')),
            const SizedBox(height: 8),
            DropdownButton<MealPlanPeriodType>(
              value: _periodType,
              items: const [
                DropdownMenuItem(value: MealPlanPeriodType.daily, child: Text('Daily')),
                DropdownMenuItem(value: MealPlanPeriodType.weekly, child: Text('Weekly')),
              ],
              onChanged: (value) => setState(() => _periodType = value ?? MealPlanPeriodType.daily),
            ),
            const SizedBox(height: 8),
            ...widget.templates.map(
              (template) => Row(
                children: [
                  Expanded(child: Text(template.name)),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () => setState(() {
                      final current = _servingsByTemplateId[template.id] ?? 0;
                      if (current > 0) _servingsByTemplateId[template.id] = current - 1;
                    }),
                  ),
                  Text('${_servingsByTemplateId[template.id] ?? 0}'),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => setState(() {
                      _servingsByTemplateId[template.id] = (_servingsByTemplateId[template.id] ?? 0) + 1;
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            final lines = <MealPlanLineInput>[];
            for (final template in widget.templates) {
              final servings = _servingsByTemplateId[template.id] ?? 0;
              if (servings > 0) {
                lines.add(MealPlanLineInput(template: template, servings: servings.toDouble()));
              }
            }
            if (lines.isEmpty) return;
            Navigator.of(context).pop(
              _PlanDraft(
                name: _name.text.trim().isEmpty ? 'My plan' : _name.text.trim(),
                periodType: _periodType,
                lines: lines,
              ),
            );
          },
          child: const Text('Create plan'),
        ),
      ],
    );
  }
}
