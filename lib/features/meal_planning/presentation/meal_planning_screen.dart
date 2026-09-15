import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/calculations/meal_plan_calculator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_label.dart';
import '../../coach/data/coach_service.dart';
import '../data/budget_repository.dart';
import '../data/meal_plan_repository.dart';
import '../data/meal_template_repository.dart';
import '../data/price_provider.dart';
import '../data/price_repository.dart';
import '../domain/budget_settings.dart';
import '../domain/meal_plan.dart';
import '../domain/meal_template.dart';
import '../domain/price_snapshot.dart';

/// Budget settings, reusable meal templates, saved/proposed meal plans, and
/// standalone price tracking in one screen — following the same "one
/// screen, no chat UI, list + simple forms" convention as
/// `ReadinessCheckInScreen`/`CoachRecommendationsScreen` for a fast-track
/// feature of this scope.
///
/// AI-proposed plans land here as `mealPlans` documents too (written only
/// via the coach `handleCommand` approve flow, never directly by this
/// screen) — this view does not distinguish source in its list beyond the
/// small "AI proposed" label, since both paths went through the same
/// deterministic calculator.
///
/// Price tracking (the "Prices" section) is deliberately a standalone
/// "what did this cost over time" record via `PriceRepository`/
/// `ManualPriceProvider` — it is NOT wired into template cost entry, which
/// stays a manually-typed number. See docs/superpowers/ISSUES.md, Phase 8
/// item 7: composing template cost from priced ingredients would edge
/// toward recipe-builder scope, which is explicitly out of scope.
class MealPlanningScreen extends StatefulWidget {
  const MealPlanningScreen({
    super.key,
    required this.uid,
    required this.budgetRepository,
    required this.templateRepository,
    required this.planRepository,
    required this.priceRepository,
    required this.coachService,
  });

  final String uid;
  final BudgetRepository budgetRepository;
  final MealTemplateRepository templateRepository;
  final MealPlanRepository planRepository;
  final PriceRepository priceRepository;

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
  List<PriceSnapshot> _prices = [];
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
      final prices = await widget.priceRepository.listAll(widget.uid);
      if (!mounted) return;
      setState(() {
        _budget = budget;
        _templates = templates;
        _plans = plans;
        _prices = prices;
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

  Future<void> _editTemplate(MealTemplate template) async {
    final result = await showDialog<MealTemplate>(
      context: context,
      builder: (context) => _TemplateEditorDialog(initial: template),
    );
    if (result == null) return;
    await widget.templateRepository.update(widget.uid, result);
    await _load();
  }

  Future<void> _deleteTemplate(MealTemplate template) async {
    final confirmed = await _confirmDelete(
      title: 'Delete template?',
      message: 'This removes "${template.name}" — it will no longer be usable for new plans.',
    );
    if (!confirmed) return;
    await widget.templateRepository.delete(widget.uid, template.id);
    await _load();
  }

  Future<void> _deletePlan(MealPlan plan) async {
    final confirmed = await _confirmDelete(
      title: 'Delete plan?',
      message: 'This removes "${plan.name}" permanently.',
    );
    if (!confirmed) return;
    await widget.planRepository.delete(widget.uid, plan.id);
    await _load();
  }

  Future<bool> _confirmDelete({required String title, required String message}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Records a manually-entered price snapshot — the only price path this
  /// screen exercises (live providers are `UnavailableLivePriceProvider`
  /// only, per Phase 8 scope). Persisted standalone via `PriceRepository`,
  /// never composed into a template's cost.
  Future<void> _recordPrice() async {
    final result = await showDialog<_PriceDraft>(
      context: context,
      builder: (context) => _PriceEditorDialog(defaultCurrency: _budget?.currency ?? 'USD'),
    );
    if (result == null) return;
    final quote = await ManualPriceProvider(manualPrice: result.price).getPrice(
      itemName: result.itemName,
      unit: result.unit,
      quantity: result.quantity,
      currency: result.currency,
    );
    await widget.priceRepository.record(widget.uid, quote.toSnapshot(''));
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
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Meal planning'), backgroundColor: Colors.transparent),
      body: AmbientBackground(
        child: SafeArea(
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
                      _TemplatesCard(
                        templates: _templates,
                        onAdd: _addTemplate,
                        onEdit: _editTemplate,
                        onDelete: _deleteTemplate,
                      ),
                      const SizedBox(height: 16),
                      _PricesCard(prices: _prices, onAdd: _recordPrice),
                      const SizedBox(height: 16),
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionLabel('Build or ask'),
                            const SizedBox(height: 8),
                            Text(
                              'Build a plan from your templates, or review one the AI coach proposed '
                              '(only saved here after you approve it in the coach screen).',
                              style: textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(child: _GlassPillButton(label: 'Build a plan', onPressed: _buildPlan)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: PrimaryButton(
                                    label: 'Ask coach',
                                    onPressed: _askingCoach ? null : _askCoach,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const SectionLabel('Saved plans'),
                      const SizedBox(height: 12),
                      if (_plans.isEmpty)
                        Text('No meal plans yet.', style: textTheme.bodyMedium)
                      else
                        ..._plans.map(
                          (plan) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _PlanCard(plan: plan, onDelete: () => _deletePlan(plan)),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// A dark/translucent stadium pill for the secondary "Build a plan" action —
/// per the handoff's meal-planning screenshot, "Build a plan" is glass while
/// "Ask coach" is the gradient [PrimaryButton], mirroring the
/// glass-vs-gradient pairing `_BackPill`/primary CTA use elsewhere (e.g.
/// `onboarding_screen.dart`).
class _GlassPillButton extends StatelessWidget {
  const _GlassPillButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.glassFillStrong,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.glassStroke)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
            ),
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
    final textTheme = Theme.of(context).textTheme;
    return GlassCard(
      hero: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Budget'),
          const SizedBox(height: 12),
          if (budget == null)
            Text(
              'No budget set yet — proposals will still show cost, just without a ceiling to check against.',
              style: textTheme.bodyMedium,
            )
          else
            Text(
              'Daily ${budget.dailyLimit?.toStringAsFixed(0) ?? '—'} · '
              'Weekly ${budget.weeklyLimit?.toStringAsFixed(0) ?? '—'} '
              '${budget.currency}',
              style: textTheme.headlineMedium?.copyWith(fontSize: 22),
            ),
          const SizedBox(height: 14),
          _GlassPillButton(label: budget == null ? 'Set a budget' : 'Edit budget', onPressed: onEdit),
        ],
      ),
    );
  }
}

class _TemplatesCard extends StatelessWidget {
  const _TemplatesCard({
    required this.templates,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final List<MealTemplate> templates;
  final VoidCallback onAdd;
  final ValueChanged<MealTemplate> onEdit;
  final ValueChanged<MealTemplate> onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Meal templates'),
          const SizedBox(height: 12),
          if (templates.isEmpty)
            Text('No templates yet.', style: textTheme.bodyMedium)
          else
            ...templates.map(
              (template) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(template.name, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            '${template.caloriesPerServing.toStringAsFixed(0)} kcal · '
                            '${template.proteinGPerServing.toStringAsFixed(0)}g · '
                            '${_costLabel(template.costPerServing, template.currency, template.costSource)}',
                            style: textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20, color: AppColors.textSecondary),
                      tooltip: 'Edit ${template.name}',
                      onPressed: () => onEdit(template),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20, color: AppColors.textSecondary),
                      tooltip: 'Delete ${template.name}',
                      onPressed: () => onDelete(template),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          _GlassPillButton(label: 'Add a template', onPressed: onAdd),
        ],
      ),
    );
  }
}

class _PricesCard extends StatelessWidget {
  const _PricesCard({required this.prices, required this.onAdd});

  final List<PriceSnapshot> prices;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Prices'),
          const SizedBox(height: 8),
          Text(
            'Track what things cost over time — a standalone record, separate from a '
            "template's per-serving cost.",
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          if (prices.isEmpty)
            Text('No prices recorded yet.', style: textTheme.bodyMedium)
          else
            ...prices.map(
              (snapshot) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        snapshot.itemName,
                        style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${_priceLabel(snapshot)} / '
                      '${snapshot.quantity.toStringAsFixed(snapshot.quantity.truncateToDouble() == snapshot.quantity ? 0 : 2)} '
                      '${snapshot.unit}',
                      textAlign: TextAlign.right,
                      style: textTheme.bodyMedium?.copyWith(color: AppColors.accentGreen),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          _GlassPillButton(label: 'Record a price', onPressed: onAdd),
        ],
      ),
    );
  }

  String _priceLabel(PriceSnapshot snapshot) {
    final price = snapshot.price;
    return price != null ? '${price.toStringAsFixed(2)} ${snapshot.currency}' : 'price unavailable';
  }

}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.onDelete});

  final MealPlan plan;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(plan.name, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: 17)),
              ),
              if (plan.source == MealPlanSource.aiProposal)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text(
                    'AI proposed',
                    style: TextStyle(color: AppColors.accentViolet, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.delete, size: 20, color: AppColors.textSecondary),
                tooltip: 'Delete ${plan.name}',
                onPressed: onDelete,
              ),
            ],
          ),
          Text('${plan.periodType.name} plan', style: textTheme.bodyMedium),
          const SizedBox(height: 10),
          Text(
            plan.totalCost != null
                ? 'Total cost: ${plan.totalCost!.toStringAsFixed(2)} ${plan.currency}'
                : 'Total cost: unavailable (one or more items are unpriced)',
            style: textTheme.bodyLarge?.copyWith(color: AppColors.accentGreen, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            plan.periodType == MealPlanPeriodType.daily
                ? 'Weekly projection: ${_projected(plan, MealPlanPeriodType.weekly)}'
                : 'Daily equivalent: ${_projected(plan, MealPlanPeriodType.daily)}',
            style: textTheme.bodyMedium,
          ),
          Text('Monthly projection: ${_monthlyProjection(plan)}', style: textTheme.bodyMedium),
          if (plan.totalCalories != null)
            Text('Total calories: ${plan.totalCalories!.toStringAsFixed(0)} kcal', style: textTheme.bodyMedium),
          if (plan.totalProteinG != null)
            Text('Total protein: ${plan.totalProteinG!.toStringAsFixed(0)} g', style: textTheme.bodyMedium),
          if (plan.proteinPerCurrencyUnit != null)
            Text(
              'Protein per ${plan.currency}: ${plan.proteinPerCurrencyUnit!.toStringAsFixed(1)} g',
              style: textTheme.bodyMedium,
            ),
          const SizedBox(height: 10),
          ...plan.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${item.templateName} x${item.servings.toStringAsFixed(item.servings.truncateToDouble() == item.servings ? 0 : 1)}'
                ' — ${item.lineCost != null ? '${item.lineCost!.toStringAsFixed(2)} ${plan.currency}' : 'unpriced'}',
                style: textTheme.bodyMedium,
              ),
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
  const _TemplateEditorDialog({this.initial});

  /// When set, the dialog pre-fills from this template and the saved result
  /// carries the same [MealTemplate.id] so the caller can `update` rather
  /// than `create`.
  final MealTemplate? initial;

  @override
  State<_TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<_TemplateEditorDialog> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _calories =
      TextEditingController(text: widget.initial?.caloriesPerServing.toString() ?? '');
  late final _protein =
      TextEditingController(text: widget.initial?.proteinGPerServing.toString() ?? '');
  late final _carbs = TextEditingController(text: widget.initial?.carbsGPerServing.toString() ?? '');
  late final _fat = TextEditingController(text: widget.initial?.fatGPerServing.toString() ?? '');
  late final _cost = TextEditingController(text: widget.initial?.costPerServing?.toString() ?? '');
  late final _currency = TextEditingController(text: widget.initial?.currency ?? 'USD');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'New meal template' : 'Edit meal template'),
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
                id: widget.initial?.id ?? '',
                name: _name.text.trim(),
                servings: widget.initial?.servings ?? 1,
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
          child: Text(widget.initial == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}

class _PriceDraft {
  const _PriceDraft({
    required this.itemName,
    required this.price,
    required this.unit,
    required this.quantity,
    required this.currency,
  });

  final String itemName;
  final double price;
  final String unit;
  final double quantity;
  final String currency;
}

class _PriceEditorDialog extends StatefulWidget {
  const _PriceEditorDialog({required this.defaultCurrency});

  final String defaultCurrency;

  @override
  State<_PriceEditorDialog> createState() => _PriceEditorDialogState();
}

class _PriceEditorDialogState extends State<_PriceEditorDialog> {
  final _itemName = TextEditingController();
  final _price = TextEditingController();
  final _unit = TextEditingController(text: 'each');
  final _quantity = TextEditingController(text: '1');
  late final TextEditingController _currency = TextEditingController(text: widget.defaultCurrency);
  String? _validationError;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record a price'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _itemName, decoration: const InputDecoration(labelText: 'Item name')),
            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Price'),
            ),
            TextField(controller: _unit, decoration: const InputDecoration(labelText: 'Unit (e.g. kg, each, lb)')),
            TextField(
              controller: _quantity,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Quantity this price covers'),
            ),
            TextField(controller: _currency, decoration: const InputDecoration(labelText: 'Currency')),
            if (_validationError != null) ...[
              const SizedBox(height: 8),
              Text(_validationError!, style: const TextStyle(color: AppColors.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            final itemName = _itemName.text.trim();
            final price = double.tryParse(_price.text.trim());
            final quantity = double.tryParse(_quantity.text.trim());
            if (itemName.isEmpty || price == null || quantity == null || quantity <= 0) {
              setState(() => _validationError = 'Enter an item name, a price, and a positive quantity.');
              return;
            }
            Navigator.of(context).pop(
              _PriceDraft(
                itemName: itemName,
                price: price,
                unit: _unit.text.trim().isEmpty ? 'each' : _unit.text.trim(),
                quantity: quantity,
                currency: _currency.text.trim().isEmpty ? 'USD' : _currency.text.trim(),
              ),
            );
          },
          child: const Text('Save'),
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
                    tooltip: 'Decrease servings of ${template.name}',
                    onPressed: () => setState(() {
                      final current = _servingsByTemplateId[template.id] ?? 0;
                      if (current > 0) _servingsByTemplateId[template.id] = current - 1;
                    }),
                  ),
                  Text('${_servingsByTemplateId[template.id] ?? 0}'),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Increase servings of ${template.name}',
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
