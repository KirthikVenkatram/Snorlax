/// Domain type for a user's grocery/food budget, persisted at
/// `users/{uid}/budgetSettings/current` (a single per-user settings
/// document, same convention as `users/{uid}/meta/adherenceWeights`).
///
/// All amounts are in whole currency units (e.g. dollars, not cents) to
/// match how the rest of the app represents money-adjacent quantities —
/// there is no existing minor-unit convention in this codebase to follow.
library;

/// One of [BudgetSettings.dailyLimit]/[weeklyLimit]/[monthlyLimit] may be
/// null if the user hasn't set a limit at that granularity; at least the
/// caller should treat "no budget set" (all null) as a valid, common state
/// (a new user) rather than an error.
class BudgetSettings {
  const BudgetSettings({
    required this.currency,
    this.dailyLimit,
    this.weeklyLimit,
    this.monthlyLimit,
    this.preferredStores = const [],
    this.substitutions = const {},
  })  : assert(dailyLimit == null || dailyLimit >= 0, 'dailyLimit must be non-negative'),
        assert(weeklyLimit == null || weeklyLimit >= 0, 'weeklyLimit must be non-negative'),
        assert(monthlyLimit == null || monthlyLimit >= 0, 'monthlyLimit must be non-negative');

  /// ISO 4217-style currency code, e.g. 'USD', 'INR'. Not validated against
  /// a fixed list — this is display/labelling metadata only, not used for
  /// any conversion math.
  final String currency;
  final double? dailyLimit;
  final double? weeklyLimit;
  final double? monthlyLimit;

  /// Free-text preferred store names (e.g. "Blinkit", "local market"),
  /// informational only — no live-provider integration reads this yet.
  final List<String> preferredStores;

  /// Item-name substitution preferences, e.g. {"almond milk": "oat milk"},
  /// informational only for this phase.
  final Map<String, String> substitutions;

  Map<String, dynamic> toJson() => {
        'currency': currency,
        'dailyLimit': dailyLimit,
        'weeklyLimit': weeklyLimit,
        'monthlyLimit': monthlyLimit,
        'preferredStores': preferredStores,
        'substitutions': substitutions,
      };

  factory BudgetSettings.fromJson(Map<String, dynamic> json) => BudgetSettings(
        currency: json['currency'] as String? ?? 'USD',
        dailyLimit: (json['dailyLimit'] as num?)?.toDouble(),
        weeklyLimit: (json['weeklyLimit'] as num?)?.toDouble(),
        monthlyLimit: (json['monthlyLimit'] as num?)?.toDouble(),
        preferredStores: (json['preferredStores'] as List? ?? const []).map((s) => s as String).toList(),
        substitutions: Map<String, String>.from(json['substitutions'] as Map? ?? const {}),
      );
}
