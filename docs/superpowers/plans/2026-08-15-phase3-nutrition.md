# Phase 3: Nutrition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add nutrition tracking to the fitness tracker: manual meal logging (search-based or natural-language), daily calorie/macro goals with progress tracking, and food data merged from USDA FoodData Central, Open Food Facts, and Nutritionix, with an LLM (Groq, falling back to NVIDIA NIM) filling gaps neither source covers — particularly home-cooked South Indian dishes.

**Architecture:** A new Flutter feature `lib/features/nutrition/` following the `{data,domain,presentation}` shape established in Phase 1/2, plus three new Firebase Cloud Functions in the existing `functions/` project (`searchFood`, `parseFoodText`, `estimateNutrition`) — all external API keys (USDA, Nutritionix, Groq, NVIDIA NIM) live only in Cloud Functions secrets, never in the client app.

**Tech Stack:** Flutter/Dart (existing), `cloud_functions` (already a dependency, added in Phase 2), Node.js/TypeScript Cloud Functions using native `fetch` (existing pattern from `stravaClient.ts`), `jest`/`ts-jest` (existing).

## Global Constraints

- Portion size is always entered in grams — no serving-size multipliers. (Spec: Scope Decisions)
- Food log entries are grouped by meal type (breakfast/lunch/dinner/snack). (Spec: Scope Decisions)
- All external food/LLM API keys are Cloud Functions secrets — never embedded in the Flutter app. (Spec: Scope Decisions, Tech Stack Additions)
- Stay within each provider's free tier (USDA, Open Food Facts, Nutritionix, Groq, NVIDIA NIM) — no paid tier is in scope for this phase. (Spec: Out of Scope)
- `searchFood`'s per-source failures are tolerated — one source failing must not fail the whole search (`Promise.allSettled`, not `Promise.all`). (Spec: Tech Stack Additions)
- `parseFoodText`/`estimateNutrition` try Groq first, then NVIDIA NIM on failure/rate-limit. (Spec: Scope Decisions)
- Food log entries are fully editable/deletable — there is no read-only source in this phase (unlike Phase 2's Strava cardio workouts). (Spec: Scope Decisions)
- A `FoodEntry`'s `calories`/`proteinG`/`carbsG`/`fatG` are the *scaled* values for that entry's `quantityGrams`, computed once at save time — not recomputed from a per-100g source on every read. (Spec: Data Model)
- Existing Firestore security rules already cover any new path under `users/{uid}/**` outside `meta` — confirmed via the current `firestore.rules`, which explicitly names `foodLogs`/`recipes` in its comment as already-covered subcollections. No rules changes needed this phase.
- Visual direction inherited from Phase 1/2: dark, near-black base with neon-glow accents and glassmorphic cards; use the existing `GlassCard`/`PrimaryButton`/`ProgressRing`/`AppColors`/`AppTypography` design-system pieces, not raw Material widgets or the celebratory `GradientButton`.
- Firestore offline persistence (already enabled app-wide) must keep working for reading/writing `foodLog`, `customFoods`, and `nutritionGoals` once an entry's nutrition values are resolved; the three Cloud Functions inherently require connectivity, same as Strava sync in Phase 2.

---

### Task 1: Nutrition domain models and NutritionRepository

**Files:**
- Create: `lib/features/nutrition/domain/food_entry.dart`
- Create: `lib/features/nutrition/data/nutrition_repository.dart`
- Test: `test/features/nutrition/data/nutrition_repository_test.dart`

**Interfaces:**
- Produces: `MealType` (breakfast/lunch/dinner/snack), `FoodSource` (usda/openFoodFacts/nutritionix/llmEstimated/custom), `FoodEntry { id, date, mealType, foodName, quantityGrams, calories, proteinG, carbsG, fatG, source }`, `NutritionGoals { dailyCalories, proteinG, carbsG, fatG }`, `NutritionRepository { Future<String> logFood(...), Future<List<FoodEntry>> listFoodLog(String uid), Future<void> updateFoodEntry(...), Future<void> deleteFoodEntry(String uid, String entryId), Future<void> setGoals(String uid, NutritionGoals goals), Future<NutritionGoals?> getGoals(String uid) }` — consumed by Tasks 6, 8, 9, 10, 11.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/nutrition/data/nutrition_repository_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/nutrition/domain/food_entry.dart';
import 'package:fitness_tracker/features/nutrition/data/nutrition_repository.dart';

void main() {
  group('NutritionRepository', () {
    test('logFood writes a food entry with scaled macros', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = NutritionRepository(firestore: firestore);

      final id = await repository.logFood(
        uid: 'uid-1',
        date: DateTime(2026, 8, 15),
        mealType: MealType.breakfast,
        foodName: 'Idli',
        quantityGrams: 150,
        calories: 195,
        proteinG: 6,
        carbsG: 40,
        fatG: 1.5,
        source: FoodSource.custom,
      );

      final entries = await repository.listFoodLog('uid-1');

      expect(entries, hasLength(1));
      expect(entries.first.id, id);
      expect(entries.first.mealType, MealType.breakfast);
      expect(entries.first.foodName, 'Idli');
      expect(entries.first.quantityGrams, 150);
      expect(entries.first.calories, 195);
      expect(entries.first.source, FoodSource.custom);
    });

    test('listFoodLog returns entries newest-first', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = NutritionRepository(firestore: firestore);

      await repository.logFood(
        uid: 'uid-1', date: DateTime(2026, 8, 1), mealType: MealType.breakfast,
        foodName: 'first', quantityGrams: 100, calories: 100, proteinG: 1,
        carbsG: 1, fatG: 1, source: FoodSource.custom);
      await repository.logFood(
        uid: 'uid-1', date: DateTime(2026, 8, 3), mealType: MealType.breakfast,
        foodName: 'third', quantityGrams: 100, calories: 100, proteinG: 1,
        carbsG: 1, fatG: 1, source: FoodSource.custom);
      await repository.logFood(
        uid: 'uid-1', date: DateTime(2026, 8, 2), mealType: MealType.breakfast,
        foodName: 'second', quantityGrams: 100, calories: 100, proteinG: 1,
        carbsG: 1, fatG: 1, source: FoodSource.custom);

      final entries = await repository.listFoodLog('uid-1');

      expect(entries.map((e) => e.foodName), ['third', 'second', 'first']);
    });

    test('updateFoodEntry modifies quantity and recomputed macros', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = NutritionRepository(firestore: firestore);

      final id = await repository.logFood(
        uid: 'uid-1', date: DateTime(2026, 8, 1), mealType: MealType.lunch,
        foodName: 'Rice', quantityGrams: 100, calories: 130, proteinG: 2.7,
        carbsG: 28, fatG: 0.3, source: FoodSource.usda);

      await repository.updateFoodEntry(
        uid: 'uid-1', entryId: id, mealType: MealType.dinner,
        quantityGrams: 200, calories: 260, proteinG: 5.4, carbsG: 56, fatG: 0.6);

      final entries = await repository.listFoodLog('uid-1');
      expect(entries.first.mealType, MealType.dinner);
      expect(entries.first.quantityGrams, 200);
      expect(entries.first.calories, 260);
    });

    test('deleteFoodEntry removes the entry', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = NutritionRepository(firestore: firestore);

      final id = await repository.logFood(
        uid: 'uid-1', date: DateTime(2026, 8, 1), mealType: MealType.snack,
        foodName: 'to delete', quantityGrams: 50, calories: 50, proteinG: 1,
        carbsG: 1, fatG: 1, source: FoodSource.custom);

      await repository.deleteFoodEntry('uid-1', id);

      final entries = await repository.listFoodLog('uid-1');
      expect(entries, isEmpty);
    });

    test('setGoals and getGoals round-trip', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = NutritionRepository(firestore: firestore);

      expect(await repository.getGoals('uid-1'), isNull);

      await repository.setGoals(
        'uid-1',
        const NutritionGoals(dailyCalories: 2000, proteinG: 150, carbsG: 200, fatG: 60));

      final goals = await repository.getGoals('uid-1');
      expect(goals!.dailyCalories, 2000);
      expect(goals.proteinG, 150);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/nutrition/data/nutrition_repository_test.dart`
Expected: FAIL — files don't exist.

- [ ] **Step 3: Implement the domain models**

```dart
// lib/features/nutrition/domain/food_entry.dart

enum MealType { breakfast, lunch, dinner, snack }

enum FoodSource { usda, openFoodFacts, nutritionix, llmEstimated, custom }

class FoodEntry {
  const FoodEntry({
    required this.id,
    required this.date,
    required this.mealType,
    required this.foodName,
    required this.quantityGrams,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.source,
  });

  final String id;
  final DateTime date;
  final MealType mealType;
  final String foodName;
  final double quantityGrams;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final FoodSource source;
}

class NutritionGoals {
  const NutritionGoals({
    required this.dailyCalories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final double dailyCalories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  Map<String, dynamic> toJson() => {
        'dailyCalories': dailyCalories,
        'proteinG': proteinG,
        'carbsG': carbsG,
        'fatG': fatG,
      };

  factory NutritionGoals.fromJson(Map<String, dynamic> json) => NutritionGoals(
        dailyCalories: (json['dailyCalories'] as num).toDouble(),
        proteinG: (json['proteinG'] as num).toDouble(),
        carbsG: (json['carbsG'] as num).toDouble(),
        fatG: (json['fatG'] as num).toDouble(),
      );
}
```

- [ ] **Step 4: Implement NutritionRepository**

```dart
// lib/features/nutrition/data/nutrition_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/food_entry.dart';

class NutritionRepository {
  // (kept as a regular assignment, not an initializing formal, so the
  // public parameter name stays `firestore` while the backing field
  // stays private as `_firestore`)
  NutritionRepository({
    required FirebaseFirestore firestore,
    // ignore: prefer_initializing_formals
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _foodLog(String uid) =>
      _firestore.collection('users').doc(uid).collection('foodLog');

  DocumentReference<Map<String, dynamic>> _goalsDoc(String uid) =>
      _firestore.collection('users').doc(uid).collection('nutritionGoals').doc('goals');

  Future<String> logFood({
    required String uid,
    required DateTime date,
    required MealType mealType,
    required String foodName,
    required double quantityGrams,
    required double calories,
    required double proteinG,
    required double carbsG,
    required double fatG,
    required FoodSource source,
  }) async {
    final doc = _foodLog(uid).doc();
    await doc.set({
      'date': Timestamp.fromDate(date),
      'mealType': mealType.name,
      'foodName': foodName,
      'quantityGrams': quantityGrams,
      'calories': calories,
      'proteinG': proteinG,
      'carbsG': carbsG,
      'fatG': fatG,
      'source': source.name,
    });
    return doc.id;
  }

  Future<List<FoodEntry>> listFoodLog(String uid) async {
    final snapshot = await _foodLog(uid).orderBy('date', descending: true).get();
    return snapshot.docs.map((doc) => _fromDoc(doc.id, doc.data())).toList();
  }

  Future<void> updateFoodEntry({
    required String uid,
    required String entryId,
    required MealType mealType,
    required double quantityGrams,
    required double calories,
    required double proteinG,
    required double carbsG,
    required double fatG,
  }) async {
    await _foodLog(uid).doc(entryId).update({
      'mealType': mealType.name,
      'quantityGrams': quantityGrams,
      'calories': calories,
      'proteinG': proteinG,
      'carbsG': carbsG,
      'fatG': fatG,
    });
  }

  Future<void> deleteFoodEntry(String uid, String entryId) async {
    await _foodLog(uid).doc(entryId).delete();
  }

  Future<void> setGoals(String uid, NutritionGoals goals) async {
    await _goalsDoc(uid).set(goals.toJson());
  }

  Future<NutritionGoals?> getGoals(String uid) async {
    final doc = await _goalsDoc(uid).get();
    if (!doc.exists) return null;
    return NutritionGoals.fromJson(doc.data()!);
  }

  FoodEntry _fromDoc(String id, Map<String, dynamic> json) {
    return FoodEntry(
      id: id,
      date: (json['date'] as Timestamp).toDate(),
      mealType: MealType.values.byName(json['mealType'] as String),
      foodName: json['foodName'] as String,
      quantityGrams: (json['quantityGrams'] as num).toDouble(),
      calories: (json['calories'] as num).toDouble(),
      proteinG: (json['proteinG'] as num).toDouble(),
      carbsG: (json['carbsG'] as num).toDouble(),
      fatG: (json['fatG'] as num).toDouble(),
      source: FoodSource.values.byName(json['source'] as String),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/nutrition/data/nutrition_repository_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/nutrition/domain/food_entry.dart lib/features/nutrition/data/nutrition_repository.dart test/features/nutrition/data/nutrition_repository_test.dart
git commit -m "Add nutrition domain models and NutritionRepository"
```

---

### Task 2: CustomFood domain model and CustomFoodRepository

**Files:**
- Create: `lib/features/nutrition/domain/custom_food.dart`
- Create: `lib/features/nutrition/data/custom_food_repository.dart`
- Test: `test/features/nutrition/data/custom_food_repository_test.dart`

**Interfaces:**
- Produces: `CustomFood { id, name, caloriesPer100g, proteinPer100g, carbsPer100g, fatPer100g }`, `CustomFoodRepository { Future<CustomFood> addCustom(String uid, {required String name, required double caloriesPer100g, required double proteinPer100g, required double carbsPer100g, required double fatPer100g}), Future<List<CustomFood>> search(String uid, String query) }` — consumed by Task 6's food search service.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/nutrition/data/custom_food_repository_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/nutrition/data/custom_food_repository.dart';

void main() {
  group('CustomFoodRepository', () {
    test('addCustom writes a custom food and search finds it by name', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = CustomFoodRepository(firestore: firestore);

      final added = await repository.addCustom(
        'uid-1',
        name: 'Amma\'s Sambar',
        caloriesPer100g: 80,
        proteinPer100g: 4,
        carbsPer100g: 12,
        fatPer100g: 2,
      );

      expect(added.name, 'Amma\'s Sambar');
      expect(added.caloriesPer100g, 80);

      final results = await repository.search('uid-1', 'sambar');
      expect(results.map((f) => f.name), contains('Amma\'s Sambar'));
    });

    test('search is case-insensitive and matches substrings', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = CustomFoodRepository(firestore: firestore);
      await repository.addCustom(
        'uid-1', name: 'Homemade Dosa', caloriesPer100g: 150,
        proteinPer100g: 3, carbsPer100g: 25, fatPer100g: 4);

      final results = await repository.search('uid-1', 'DOSA');

      expect(results, isNotEmpty);
      expect(results.every((f) => f.name.toLowerCase().contains('dosa')), isTrue);
    });

    test('search returns nothing for an unrelated query', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = CustomFoodRepository(firestore: firestore);
      await repository.addCustom(
        'uid-1', name: 'Homemade Dosa', caloriesPer100g: 150,
        proteinPer100g: 3, carbsPer100g: 25, fatPer100g: 4);

      final results = await repository.search('uid-1', 'pizza');

      expect(results, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/nutrition/data/custom_food_repository_test.dart`
Expected: FAIL — files don't exist.

- [ ] **Step 3: Implement the CustomFood model**

```dart
// lib/features/nutrition/domain/custom_food.dart
class CustomFood {
  const CustomFood({
    required this.id,
    required this.name,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
  });

  final String id;
  final String name;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;

  Map<String, dynamic> toJson() => {
        'name': name,
        'caloriesPer100g': caloriesPer100g,
        'proteinPer100g': proteinPer100g,
        'carbsPer100g': carbsPer100g,
        'fatPer100g': fatPer100g,
      };

  factory CustomFood.fromJson(String id, Map<String, dynamic> json) {
    return CustomFood(
      id: id,
      name: json['name'] as String,
      caloriesPer100g: (json['caloriesPer100g'] as num).toDouble(),
      proteinPer100g: (json['proteinPer100g'] as num).toDouble(),
      carbsPer100g: (json['carbsPer100g'] as num).toDouble(),
      fatPer100g: (json['fatPer100g'] as num).toDouble(),
    );
  }
}
```

- [ ] **Step 4: Implement CustomFoodRepository**

```dart
// lib/features/nutrition/data/custom_food_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/custom_food.dart';

class CustomFoodRepository {
  // (kept as a regular assignment, not an initializing formal, so the
  // public parameter name stays `firestore` while the backing field
  // stays private as `_firestore`)
  CustomFoodRepository({
    required FirebaseFirestore firestore,
    // ignore: prefer_initializing_formals
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _firestore.collection('users').doc(uid).collection('customFoods');

  Future<CustomFood> addCustom(
    String uid, {
    required String name,
    required double caloriesPer100g,
    required double proteinPer100g,
    required double carbsPer100g,
    required double fatPer100g,
  }) async {
    final doc = _collection(uid).doc();
    final food = CustomFood(
      id: doc.id,
      name: name,
      caloriesPer100g: caloriesPer100g,
      proteinPer100g: proteinPer100g,
      carbsPer100g: carbsPer100g,
      fatPer100g: fatPer100g,
    );
    await doc.set(food.toJson());
    return food;
  }

  Future<List<CustomFood>> search(String uid, String query) async {
    final snapshot = await _collection(uid).get();
    final normalizedQuery = query.toLowerCase();
    return snapshot.docs
        .map((doc) => CustomFood.fromJson(doc.id, doc.data()))
        .where((f) => f.name.toLowerCase().contains(normalizedQuery))
        .toList();
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/nutrition/data/custom_food_repository_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/nutrition/domain/custom_food.dart lib/features/nutrition/data/custom_food_repository.dart test/features/nutrition/data/custom_food_repository_test.dart
git commit -m "Add CustomFood model and CustomFoodRepository"
```

---

### Task 3: Cloud Function foodSources.ts and searchFood

**Files:**
- Create: `functions/src/foodSources.ts`
- Create: `functions/src/searchFood.ts`
- Test: `functions/src/searchFood.test.ts`
- Modify: `functions/src/index.ts`

**Interfaces:**
- Produces: `FoodSearchHit { name: string; source: 'usda' | 'openFoodFacts' | 'nutritionix'; caloriesPer100g: number; proteinPer100g: number; carbsPer100g: number; fatPer100g: number }`, `foodSources.searchUsda(query): Promise<FoodSearchHit[]>`, `foodSources.searchOpenFoodFacts(query): Promise<FoodSearchHit[]>`, `foodSources.searchNutritionix(query): Promise<FoodSearchHit[]>`, `searchFood` (callable Cloud Function taking `{ query: string }`, returning `{ results: FoodSearchHit[] }`) — consumed by Task 6's Flutter food search service.

- [ ] **Step 1: Write the failing test**

```typescript
// functions/src/searchFood.test.ts
import { searchFoodHandler } from './searchFood';
import * as foodSources from './foodSources';

jest.mock('./foodSources');

describe('searchFoodHandler', () => {
  it('merges results from all three sources', async () => {
    (foodSources.searchUsda as jest.Mock).mockResolvedValue([
      { name: 'White Rice', source: 'usda', caloriesPer100g: 130, proteinPer100g: 2.7, carbsPer100g: 28, fatPer100g: 0.3 },
    ]);
    (foodSources.searchOpenFoodFacts as jest.Mock).mockResolvedValue([
      { name: 'Basmati Rice', source: 'openFoodFacts', caloriesPer100g: 121, proteinPer100g: 3.5, carbsPer100g: 25, fatPer100g: 0.4 },
    ]);
    (foodSources.searchNutritionix as jest.Mock).mockResolvedValue([
      { name: 'Cooked Rice', source: 'nutritionix', caloriesPer100g: 128, proteinPer100g: 2.4, carbsPer100g: 28, fatPer100g: 0.2 },
    ]);

    const result = await searchFoodHandler('rice');

    expect(result.results).toHaveLength(3);
    expect(result.results.map((r) => r.source)).toEqual(
      expect.arrayContaining(['usda', 'openFoodFacts', 'nutritionix']),
    );
  });

  it('tolerates one source failing and still returns the others', async () => {
    (foodSources.searchUsda as jest.Mock).mockResolvedValue([
      { name: 'White Rice', source: 'usda', caloriesPer100g: 130, proteinPer100g: 2.7, carbsPer100g: 28, fatPer100g: 0.3 },
    ]);
    (foodSources.searchOpenFoodFacts as jest.Mock).mockRejectedValue(new Error('OFF down'));
    (foodSources.searchNutritionix as jest.Mock).mockResolvedValue([]);

    const result = await searchFoodHandler('rice');

    expect(result.results).toHaveLength(1);
    expect(result.results[0].source).toBe('usda');
  });

  it('returns an empty list if every source fails', async () => {
    (foodSources.searchUsda as jest.Mock).mockRejectedValue(new Error('down'));
    (foodSources.searchOpenFoodFacts as jest.Mock).mockRejectedValue(new Error('down'));
    (foodSources.searchNutritionix as jest.Mock).mockRejectedValue(new Error('down'));

    const result = await searchFoodHandler('anything');

    expect(result.results).toEqual([]);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd functions && npm test -- searchFood.test.ts`
Expected: FAIL — `searchFood.ts`/`foodSources.ts` don't exist.

- [ ] **Step 3: Implement foodSources.ts**

```typescript
// functions/src/foodSources.ts
export interface FoodSearchHit {
  name: string;
  source: 'usda' | 'openFoodFacts' | 'nutritionix';
  caloriesPer100g: number;
  proteinPer100g: number;
  carbsPer100g: number;
  fatPer100g: number;
}

// Read at call time (not module load) so emulator/test setups that populate
// the environment after import still see the configured credentials.
function usdaApiKey(): string {
  return process.env.USDA_API_KEY ?? '';
}

function nutritionixCredentials(): { appId: string; appKey: string } {
  return {
    appId: process.env.NUTRITIONIX_APP_ID ?? '',
    appKey: process.env.NUTRITIONIX_APP_KEY ?? '',
  };
}

function nutrientValue(nutrients: Array<{ nutrientName: string; value: number }>, name: string): number {
  return nutrients.find((n) => n.nutrientName === name)?.value ?? 0;
}

export async function searchUsda(query: string): Promise<FoodSearchHit[]> {
  const url = `https://api.nal.usda.gov/fdc/v1/foods/search?query=${encodeURIComponent(query)}&pageSize=5&api_key=${usdaApiKey()}`;
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`USDA search failed: ${response.status}`);
  }
  const data = (await response.json()) as { foods?: Array<{ description: string; foodNutrients: Array<{ nutrientName: string; value: number }> }> };
  return (data.foods ?? []).map((food) => ({
    name: food.description,
    source: 'usda' as const,
    caloriesPer100g: nutrientValue(food.foodNutrients, 'Energy'),
    proteinPer100g: nutrientValue(food.foodNutrients, 'Protein'),
    carbsPer100g: nutrientValue(food.foodNutrients, 'Carbohydrate, by difference'),
    fatPer100g: nutrientValue(food.foodNutrients, 'Total lipid (fat)'),
  }));
}

export async function searchOpenFoodFacts(query: string): Promise<FoodSearchHit[]> {
  const url = `https://world.openfoodfacts.org/cgi/search.pl?search_terms=${encodeURIComponent(query)}&search_simple=1&action=process&json=1&page_size=5`;
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Open Food Facts search failed: ${response.status}`);
  }
  const data = (await response.json()) as {
    products?: Array<{ product_name?: string; nutriments?: Record<string, number> }>;
  };
  return (data.products ?? [])
    .filter((p) => p.product_name && p.nutriments)
    .map((p) => ({
      name: p.product_name!,
      source: 'openFoodFacts' as const,
      caloriesPer100g: p.nutriments?.['energy-kcal_100g'] ?? 0,
      proteinPer100g: p.nutriments?.['proteins_100g'] ?? 0,
      carbsPer100g: p.nutriments?.['carbohydrates_100g'] ?? 0,
      fatPer100g: p.nutriments?.['fat_100g'] ?? 0,
    }));
}

export async function searchNutritionix(query: string): Promise<FoodSearchHit[]> {
  const { appId, appKey } = nutritionixCredentials();
  const response = await fetch('https://trackapi.nutritionix.com/v2/natural/nutrients', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-app-id': appId,
      'x-app-key': appKey,
    },
    body: JSON.stringify({ query }),
  });
  if (!response.ok) {
    throw new Error(`Nutritionix search failed: ${response.status}`);
  }
  const data = (await response.json()) as {
    foods?: Array<{
      food_name: string;
      serving_weight_grams: number;
      nf_calories: number;
      nf_protein: number;
      nf_total_carbohydrate: number;
      nf_total_fat: number;
    }>;
  };
  return (data.foods ?? []).map((food) => {
    const grams = food.serving_weight_grams || 100;
    const scale = 100 / grams;
    return {
      name: food.food_name,
      source: 'nutritionix' as const,
      caloriesPer100g: food.nf_calories * scale,
      proteinPer100g: food.nf_protein * scale,
      carbsPer100g: food.nf_total_carbohydrate * scale,
      fatPer100g: food.nf_total_fat * scale,
    };
  });
}
```

- [ ] **Step 4: Implement searchFood.ts**

```typescript
// functions/src/searchFood.ts
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as foodSources from './foodSources';
import type { FoodSearchHit } from './foodSources';

export async function searchFoodHandler(query: string): Promise<{ results: FoodSearchHit[] }> {
  const settled = await Promise.allSettled([
    foodSources.searchUsda(query),
    foodSources.searchOpenFoodFacts(query),
    foodSources.searchNutritionix(query),
  ]);

  const results: FoodSearchHit[] = [];
  for (const outcome of settled) {
    if (outcome.status === 'fulfilled') {
      results.push(...outcome.value);
    } else {
      console.error('Food source search failed', outcome.reason);
    }
  }
  return { results };
}

export const searchFood = onCall(
  { secrets: ['USDA_API_KEY', 'NUTRITIONIX_APP_ID', 'NUTRITIONIX_APP_KEY'] },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'Must be signed in.');
    }
    const query = request.data?.query as string | undefined;
    if (!query) {
      throw new HttpsError('invalid-argument', 'Missing search query.');
    }
    return searchFoodHandler(query);
  },
);
```

- [ ] **Step 5: Wire the function into index.ts**

```typescript
// functions/src/index.ts
import * as admin from 'firebase-admin';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

export { exchangeStravaToken } from './exchangeStravaToken';
export { stravaWebhook } from './stravaWebhook';
export { searchFood } from './searchFood';
```

- [ ] **Step 6: Run test to verify it passes**

Run: `cd functions && npm test -- searchFood.test.ts`
Expected: PASS (3 tests).

- [ ] **Step 7: Run TypeScript compilation to catch type errors**

Run: `cd functions && npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 8: Commit**

```bash
git add functions/src/foodSources.ts functions/src/searchFood.ts functions/src/searchFood.test.ts functions/src/index.ts
git commit -m "Add foodSources multi-provider search and searchFood function"
```

---

### Task 4: Cloud Function llmClient.ts with Groq/NVIDIA NIM fallback

**Files:**
- Create: `functions/src/llmClient.ts`
- Test: `functions/src/llmClient.test.ts`

**Interfaces:**
- Produces: `llmClient.generateText(prompt: string): Promise<string>` — tries Groq first, falls back to NVIDIA NIM on any failure; consumed by Task 5's `parseFoodText` and `estimateNutrition` functions.

- [ ] **Step 1: Write the failing test**

```typescript
// functions/src/llmClient.test.ts
import { generateText } from './llmClient';

const originalFetch = global.fetch;

describe('generateText', () => {
  afterEach(() => {
    global.fetch = originalFetch;
  });

  it('returns Groq\'s response when Groq succeeds', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ choices: [{ message: { content: 'groq response' } }] }),
    }) as unknown as typeof fetch;

    const result = await generateText('a prompt');

    expect(result).toBe('groq response');
    expect(global.fetch).toHaveBeenCalledTimes(1);
    expect((global.fetch as jest.Mock).mock.calls[0][0]).toContain('groq.com');
  });

  it('falls back to NVIDIA NIM when Groq fails', async () => {
    global.fetch = jest
      .fn()
      .mockResolvedValueOnce({ ok: false, status: 429 })
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({ choices: [{ message: { content: 'nim response' } }] }),
      }) as unknown as typeof fetch;

    const result = await generateText('a prompt');

    expect(result).toBe('nim response');
    expect(global.fetch).toHaveBeenCalledTimes(2);
    expect((global.fetch as jest.Mock).mock.calls[1][0]).toContain('nvidia.com');
  });

  it('throws if both Groq and NVIDIA NIM fail', async () => {
    global.fetch = jest
      .fn()
      .mockResolvedValueOnce({ ok: false, status: 500 })
      .mockResolvedValueOnce({ ok: false, status: 500 }) as unknown as typeof fetch;

    await expect(generateText('a prompt')).rejects.toThrow();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd functions && npm test -- llmClient.test.ts`
Expected: FAIL — `llmClient.ts` doesn't exist.

- [ ] **Step 3: Implement llmClient.ts**

```typescript
// functions/src/llmClient.ts

// Read at call time (not module load) so emulator/test setups that populate
// the environment after import still see the configured credentials.
function groqApiKey(): string {
  return process.env.GROQ_API_KEY ?? '';
}

function nimApiKey(): string {
  return process.env.NVIDIA_NIM_API_KEY ?? '';
}

interface ChatCompletionResponse {
  choices: Array<{ message: { content: string } }>;
}

async function callGroq(prompt: string): Promise<string> {
  const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${groqApiKey()}`,
    },
    body: JSON.stringify({
      model: 'llama-3.3-70b-versatile',
      messages: [{ role: 'user', content: prompt }],
      temperature: 0,
    }),
  });
  if (!response.ok) {
    throw new Error(`Groq request failed: ${response.status}`);
  }
  const data = (await response.json()) as ChatCompletionResponse;
  return data.choices[0].message.content;
}

async function callNvidiaNim(prompt: string): Promise<string> {
  const response = await fetch('https://integrate.api.nvidia.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${nimApiKey()}`,
    },
    body: JSON.stringify({
      model: 'meta/llama-3.1-70b-instruct',
      messages: [{ role: 'user', content: prompt }],
      temperature: 0,
    }),
  });
  if (!response.ok) {
    throw new Error(`NVIDIA NIM request failed: ${response.status}`);
  }
  const data = (await response.json()) as ChatCompletionResponse;
  return data.choices[0].message.content;
}

/**
 * Tries Groq first (fast, generous free tier); falls back to NVIDIA NIM if
 * Groq errors or is rate-limited. Throws only if both fail.
 */
export async function generateText(prompt: string): Promise<string> {
  try {
    return await callGroq(prompt);
  } catch (groqError) {
    console.error('Groq request failed, falling back to NVIDIA NIM', groqError);
    return callNvidiaNim(prompt);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd functions && npm test -- llmClient.test.ts`
Expected: PASS (3 tests).

- [ ] **Step 5: Run TypeScript compilation to catch type errors**

Run: `cd functions && npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add functions/src/llmClient.ts functions/src/llmClient.test.ts
git commit -m "Add llmClient with Groq primary and NVIDIA NIM fallback"
```

---

### Task 5: Cloud Functions parseFoodText and estimateNutrition

**Files:**
- Create: `functions/src/parseFoodText.ts`
- Create: `functions/src/estimateNutrition.ts`
- Test: `functions/src/parseFoodText.test.ts`
- Test: `functions/src/estimateNutrition.test.ts`
- Modify: `functions/src/index.ts`

**Interfaces:**
- Consumes: `llmClient.generateText` (Task 4).
- Produces: `ParsedFoodItem { foodName: string; estimatedQuantityGrams: number }`, `parseFoodText` (callable, `{ text: string }` → `{ items: ParsedFoodItem[] }`), `EstimatedNutrition { caloriesPer100g: number; proteinPer100g: number; carbsPer100g: number; fatPer100g: number }`, `estimateNutrition` (callable, `{ foodName: string }` → `EstimatedNutrition`) — both consumed by Task 6's Flutter food search service.

- [ ] **Step 1: Write the failing tests**

```typescript
// functions/src/parseFoodText.test.ts
import { parseFoodTextHandler } from './parseFoodText';
import * as llmClient from './llmClient';

jest.mock('./llmClient');

describe('parseFoodTextHandler', () => {
  it('parses natural language into structured food items', async () => {
    (llmClient.generateText as jest.Mock).mockResolvedValue(
      '[{"foodName": "Idli", "estimatedQuantityGrams": 150}, {"foodName": "Sambar", "estimatedQuantityGrams": 200}]',
    );

    const result = await parseFoodTextHandler('2 idlis and a cup of sambar');

    expect(result.items).toEqual([
      { foodName: 'Idli', estimatedQuantityGrams: 150 },
      { foodName: 'Sambar', estimatedQuantityGrams: 200 },
    ]);
  });

  it('extracts a JSON array even if the model wraps it in prose or markdown', async () => {
    (llmClient.generateText as jest.Mock).mockResolvedValue(
      'Here you go:\n```json\n[{"foodName": "Rice", "estimatedQuantityGrams": 100}]\n```',
    );

    const result = await parseFoodTextHandler('rice');

    expect(result.items).toEqual([{ foodName: 'Rice', estimatedQuantityGrams: 100 }]);
  });

  it('throws if the model response has no parseable JSON array', async () => {
    (llmClient.generateText as jest.Mock).mockResolvedValue('I cannot help with that.');

    await expect(parseFoodTextHandler('gibberish')).rejects.toThrow();
  });
});
```

```typescript
// functions/src/estimateNutrition.test.ts
import { estimateNutritionHandler } from './estimateNutrition';
import * as llmClient from './llmClient';

jest.mock('./llmClient');

describe('estimateNutritionHandler', () => {
  it('parses an LLM nutrition estimate into structured fields', async () => {
    (llmClient.generateText as jest.Mock).mockResolvedValue(
      '{"caloriesPer100g": 195, "proteinPer100g": 6, "carbsPer100g": 40, "fatPer100g": 1.5}',
    );

    const result = await estimateNutritionHandler('Idli');

    expect(result).toEqual({
      caloriesPer100g: 195,
      proteinPer100g: 6,
      carbsPer100g: 40,
      fatPer100g: 1.5,
    });
  });

  it('throws if the model response has no parseable JSON object', async () => {
    (llmClient.generateText as jest.Mock).mockResolvedValue('no idea');

    await expect(estimateNutritionHandler('Unknown Food')).rejects.toThrow();
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd functions && npm test -- parseFoodText.test.ts estimateNutrition.test.ts`
Expected: FAIL — files don't exist.

- [ ] **Step 3: Implement parseFoodText.ts**

```typescript
// functions/src/parseFoodText.ts
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as llmClient from './llmClient';

export interface ParsedFoodItem {
  foodName: string;
  estimatedQuantityGrams: number;
}

/**
 * Extracts the first JSON array literal from a model response, tolerating
 * surrounding prose or a markdown code fence — models don't reliably return
 * bare JSON even when asked to.
 */
function extractJsonArray(text: string): unknown[] {
  const match = text.match(/\[[\s\S]*\]/);
  if (!match) {
    throw new Error('No JSON array found in model response');
  }
  return JSON.parse(match[0]) as unknown[];
}

export async function parseFoodTextHandler(text: string): Promise<{ items: ParsedFoodItem[] }> {
  const prompt = `Extract each distinct food item from this meal description as a JSON array of objects with "foodName" and "estimatedQuantityGrams" (a reasonable gram estimate for the portion described). Respond with ONLY the JSON array, no other text.\n\nMeal description: "${text}"`;

  const response = await llmClient.generateText(prompt);
  const parsed = extractJsonArray(response);

  const items: ParsedFoodItem[] = parsed.map((item) => {
    const record = item as Record<string, unknown>;
    return {
      foodName: String(record.foodName),
      estimatedQuantityGrams: Number(record.estimatedQuantityGrams),
    };
  });

  return { items };
}

export const parseFoodText = onCall(
  { secrets: ['GROQ_API_KEY', 'NVIDIA_NIM_API_KEY'] },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'Must be signed in.');
    }
    const text = request.data?.text as string | undefined;
    if (!text) {
      throw new HttpsError('invalid-argument', 'Missing meal description text.');
    }
    return parseFoodTextHandler(text);
  },
);
```

- [ ] **Step 4: Implement estimateNutrition.ts**

```typescript
// functions/src/estimateNutrition.ts
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as llmClient from './llmClient';

export interface EstimatedNutrition {
  caloriesPer100g: number;
  proteinPer100g: number;
  carbsPer100g: number;
  fatPer100g: number;
}

/**
 * Extracts the first JSON object literal from a model response, tolerating
 * surrounding prose or a markdown code fence.
 */
function extractJsonObject(text: string): Record<string, unknown> {
  const match = text.match(/\{[\s\S]*\}/);
  if (!match) {
    throw new Error('No JSON object found in model response');
  }
  return JSON.parse(match[0]) as Record<string, unknown>;
}

export async function estimateNutritionHandler(foodName: string): Promise<EstimatedNutrition> {
  const prompt = `Estimate the nutrition per 100g for this food as a JSON object with keys "caloriesPer100g", "proteinPer100g", "carbsPer100g", "fatPer100g" (all numbers). Respond with ONLY the JSON object, no other text.\n\nFood: "${foodName}"`;

  const response = await llmClient.generateText(prompt);
  const parsed = extractJsonObject(response);

  return {
    caloriesPer100g: Number(parsed.caloriesPer100g),
    proteinPer100g: Number(parsed.proteinPer100g),
    carbsPer100g: Number(parsed.carbsPer100g),
    fatPer100g: Number(parsed.fatPer100g),
  };
}

export const estimateNutrition = onCall(
  { secrets: ['GROQ_API_KEY', 'NVIDIA_NIM_API_KEY'] },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'Must be signed in.');
    }
    const foodName = request.data?.foodName as string | undefined;
    if (!foodName) {
      throw new HttpsError('invalid-argument', 'Missing foodName.');
    }
    return estimateNutritionHandler(foodName);
  },
);
```

- [ ] **Step 5: Wire both functions into index.ts**

```typescript
// functions/src/index.ts
import * as admin from 'firebase-admin';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

export { exchangeStravaToken } from './exchangeStravaToken';
export { stravaWebhook } from './stravaWebhook';
export { searchFood } from './searchFood';
export { parseFoodText } from './parseFoodText';
export { estimateNutrition } from './estimateNutrition';
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd functions && npm test -- parseFoodText.test.ts estimateNutrition.test.ts`
Expected: PASS (5 tests total).

- [ ] **Step 7: Run full functions test suite and TypeScript compilation**

Run: `cd functions && npx tsc --noEmit && npm test`
Expected: no compile errors, all tests pass.

- [ ] **Step 8: Commit**

```bash
git add functions/src/parseFoodText.ts functions/src/estimateNutrition.ts functions/src/parseFoodText.test.ts functions/src/estimateNutrition.test.ts functions/src/index.ts
git commit -m "Add parseFoodText and estimateNutrition Cloud Functions"
```

---

### Task 6: Flutter FoodSearchResult model and FoodSearchService

**Files:**
- Create: `lib/features/nutrition/domain/food_search_result.dart`
- Create: `lib/features/nutrition/data/food_search_service.dart`
- Test: `test/features/nutrition/data/food_search_service_test.dart`

**Interfaces:**
- Consumes: `CustomFoodRepository` (Task 2), `cloud_functions`'s `FirebaseFunctions`.
- Produces: `FoodSearchResult { name, source, caloriesPer100g, proteinPer100g, carbsPer100g, fatPer100g }`, `ParsedFoodItem { foodName, estimatedQuantityGrams }`, `FoodSearchService { Future<List<FoodSearchResult>> search(String uid, String query), Future<List<ParsedFoodItem>> parseText(String text), Future<FoodSearchResult> estimateNutrition(String foodName) }` — consumed by Task 7's food picker and Task 8's log-food screen.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/nutrition/data/food_search_service_test.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fitness_tracker/features/nutrition/data/custom_food_repository.dart';
import 'package:fitness_tracker/features/nutrition/data/food_search_service.dart';
import 'package:fitness_tracker/features/nutrition/domain/food_entry.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult<T> extends Mock implements HttpsCallableResult<T> {}

void main() {
  group('FoodSearchService', () {
    late MockFirebaseFunctions functions;
    late FakeFirebaseFirestore firestore;
    late CustomFoodRepository customFoodRepository;
    late FoodSearchService service;

    setUp(() {
      functions = MockFirebaseFunctions();
      firestore = FakeFirebaseFirestore();
      customFoodRepository = CustomFoodRepository(firestore: firestore);
      service = FoodSearchService(functions: functions, customFoodRepository: customFoodRepository);
    });

    test('search merges Cloud Function results with matching custom foods', () async {
      await customFoodRepository.addCustom(
        'uid-1', name: 'Amma\'s Sambar', caloriesPer100g: 80,
        proteinPer100g: 4, carbsPer100g: 12, fatPer100g: 2);

      final callable = MockHttpsCallable();
      final result = MockHttpsCallableResult<Map<String, dynamic>>();
      when(() => functions.httpsCallable('searchFood')).thenReturn(callable);
      when(() => callable.call<Map<String, dynamic>>(any())).thenAnswer((_) async => result);
      when(() => result.data).thenReturn({
        'results': [
          {
            'name': 'Sambar (canned)',
            'source': 'openFoodFacts',
            'caloriesPer100g': 70,
            'proteinPer100g': 3,
            'carbsPer100g': 10,
            'fatPer100g': 1,
          },
        ],
      });

      final results = await service.search('uid-1', 'sambar');

      expect(results, hasLength(2));
      expect(results.map((r) => r.name), containsAll(['Sambar (canned)', 'Amma\'s Sambar']));
      expect(
        results.firstWhere((r) => r.name == 'Amma\'s Sambar').source,
        FoodSource.custom,
      );
    });

    test('parseText calls parseFoodText and returns structured items', () async {
      final callable = MockHttpsCallable();
      final result = MockHttpsCallableResult<Map<String, dynamic>>();
      when(() => functions.httpsCallable('parseFoodText')).thenReturn(callable);
      when(() => callable.call<Map<String, dynamic>>(any())).thenAnswer((_) async => result);
      when(() => result.data).thenReturn({
        'items': [
          {'foodName': 'Idli', 'estimatedQuantityGrams': 150},
        ],
      });

      final items = await service.parseText('2 idlis');

      expect(items, hasLength(1));
      expect(items.first.foodName, 'Idli');
      expect(items.first.estimatedQuantityGrams, 150);
    });

    test('estimateNutrition calls estimateNutrition and tags the result as llmEstimated', () async {
      final callable = MockHttpsCallable();
      final result = MockHttpsCallableResult<Map<String, dynamic>>();
      when(() => functions.httpsCallable('estimateNutrition')).thenReturn(callable);
      when(() => callable.call<Map<String, dynamic>>(any())).thenAnswer((_) async => result);
      when(() => result.data).thenReturn({
        'caloriesPer100g': 195,
        'proteinPer100g': 6,
        'carbsPer100g': 40,
        'fatPer100g': 1.5,
      });

      final estimate = await service.estimateNutrition('Idli');

      expect(estimate.name, 'Idli');
      expect(estimate.source, FoodSource.llmEstimated);
      expect(estimate.caloriesPer100g, 195);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/nutrition/data/food_search_service_test.dart`
Expected: FAIL — files don't exist.

- [ ] **Step 3: Implement the FoodSearchResult and ParsedFoodItem models**

```dart
// lib/features/nutrition/domain/food_search_result.dart
import 'food_entry.dart';

class FoodSearchResult {
  const FoodSearchResult({
    required this.name,
    required this.source,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
  });

  final String name;
  final FoodSource source;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;

  factory FoodSearchResult.fromCloudFunctionJson(Map<String, dynamic> json) {
    return FoodSearchResult(
      name: json['name'] as String,
      source: FoodSource.values.byName(json['source'] as String),
      caloriesPer100g: (json['caloriesPer100g'] as num).toDouble(),
      proteinPer100g: (json['proteinPer100g'] as num).toDouble(),
      carbsPer100g: (json['carbsPer100g'] as num).toDouble(),
      fatPer100g: (json['fatPer100g'] as num).toDouble(),
    );
  }
}

class ParsedFoodItem {
  const ParsedFoodItem({required this.foodName, required this.estimatedQuantityGrams});

  final String foodName;
  final double estimatedQuantityGrams;

  factory ParsedFoodItem.fromJson(Map<String, dynamic> json) {
    return ParsedFoodItem(
      foodName: json['foodName'] as String,
      estimatedQuantityGrams: (json['estimatedQuantityGrams'] as num).toDouble(),
    );
  }
}
```

- [ ] **Step 4: Implement FoodSearchService**

```dart
// lib/features/nutrition/data/food_search_service.dart
import 'package:cloud_functions/cloud_functions.dart';
import '../domain/food_entry.dart';
import '../domain/food_search_result.dart';
import 'custom_food_repository.dart';

class FoodSearchService {
  FoodSearchService({
    required FirebaseFunctions functions,
    required CustomFoodRepository customFoodRepository,
  })  : _functions = functions,
        _customFoodRepository = customFoodRepository;

  final FirebaseFunctions _functions;
  final CustomFoodRepository _customFoodRepository;

  // Exposes the underlying repository so presentation-layer widgets (e.g.
  // the add-custom-food form) can add entries without threading a second
  // repository instance through every constructor.
  CustomFoodRepository get customFoodRepository => _customFoodRepository;

  Future<List<FoodSearchResult>> search(String uid, String query) async {
    final callable = _functions.httpsCallable('searchFood');
    final response = await callable.call<Map<String, dynamic>>({'query': query});
    final externalResults = (response.data['results'] as List)
        .map((r) => FoodSearchResult.fromCloudFunctionJson(r as Map<String, dynamic>))
        .toList();

    final customFoods = await _customFoodRepository.search(uid, query);
    final customResults = customFoods.map((f) => FoodSearchResult(
          name: f.name,
          source: FoodSource.custom,
          caloriesPer100g: f.caloriesPer100g,
          proteinPer100g: f.proteinPer100g,
          carbsPer100g: f.carbsPer100g,
          fatPer100g: f.fatPer100g,
        ));

    return [...externalResults, ...customResults];
  }

  Future<List<ParsedFoodItem>> parseText(String text) async {
    final callable = _functions.httpsCallable('parseFoodText');
    final response = await callable.call<Map<String, dynamic>>({'text': text});
    return (response.data['items'] as List)
        .map((i) => ParsedFoodItem.fromJson(i as Map<String, dynamic>))
        .toList();
  }

  Future<FoodSearchResult> estimateNutrition(String foodName) async {
    final callable = _functions.httpsCallable('estimateNutrition');
    final response = await callable.call<Map<String, dynamic>>({'foodName': foodName});
    final data = response.data;
    return FoodSearchResult(
      name: foodName,
      source: FoodSource.llmEstimated,
      caloriesPer100g: (data['caloriesPer100g'] as num).toDouble(),
      proteinPer100g: (data['proteinPer100g'] as num).toDouble(),
      carbsPer100g: (data['carbsPer100g'] as num).toDouble(),
      fatPer100g: (data['fatPer100g'] as num).toDouble(),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/nutrition/data/food_search_service_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Run analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 7: Commit**

```bash
git add lib/features/nutrition/domain/food_search_result.dart lib/features/nutrition/data/food_search_service.dart test/features/nutrition/data/food_search_service_test.dart
git commit -m "Add FoodSearchResult model and FoodSearchService"
```

---

### Task 7: Food picker widget (search + add-custom)

**Files:**
- Create: `lib/features/nutrition/presentation/food_picker.dart`
- Test: `test/features/nutrition/presentation/food_picker_test.dart`

**Interfaces:**
- Consumes: `FoodSearchResult`, `FoodSearchService` (Task 6), `GlassCard` (Phase 1).
- Produces: `FoodPicker({required String uid, required FoodSearchService searchService, required ValueChanged<FoodSearchResult> onSelected})` — consumed by Task 8's log-food screen.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/nutrition/presentation/food_picker_test.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fitness_tracker/features/nutrition/data/custom_food_repository.dart';
import 'package:fitness_tracker/features/nutrition/data/food_search_service.dart';
import 'package:fitness_tracker/features/nutrition/domain/food_search_result.dart';
import 'package:fitness_tracker/features/nutrition/presentation/food_picker.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult<T> extends Mock implements HttpsCallableResult<T> {}

void main() {
  testWidgets('FoodPicker shows search results and calls onSelected on tap', (tester) async {
    final functions = MockFirebaseFunctions();
    final firestore = FakeFirebaseFirestore();
    final customFoodRepository = CustomFoodRepository(firestore: firestore);
    final searchService = FoodSearchService(functions: functions, customFoodRepository: customFoodRepository);

    final callable = MockHttpsCallable();
    final result = MockHttpsCallableResult<Map<String, dynamic>>();
    when(() => functions.httpsCallable('searchFood')).thenReturn(callable);
    when(() => callable.call<Map<String, dynamic>>(any())).thenAnswer((_) async => result);
    when(() => result.data).thenReturn({
      'results': [
        {
          'name': 'White Rice',
          'source': 'usda',
          'caloriesPer100g': 130,
          'proteinPer100g': 2.7,
          'carbsPer100g': 28,
          'fatPer100g': 0.3,
        },
      ],
    });

    FoodSearchResult? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: FoodPicker(
          uid: 'uid-1',
          searchService: searchService,
          onSelected: (r) => selected = r,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'rice');
    await tester.pumpAndSettle();

    expect(find.text('White Rice'), findsOneWidget);

    await tester.tap(find.text('White Rice'));
    await tester.pumpAndSettle();

    expect(selected?.name, 'White Rice');
  });

  testWidgets('FoodPicker offers to add a custom food when search has no results', (tester) async {
    final functions = MockFirebaseFunctions();
    final firestore = FakeFirebaseFirestore();
    final customFoodRepository = CustomFoodRepository(firestore: firestore);
    final searchService = FoodSearchService(functions: functions, customFoodRepository: customFoodRepository);

    final callable = MockHttpsCallable();
    final result = MockHttpsCallableResult<Map<String, dynamic>>();
    when(() => functions.httpsCallable('searchFood')).thenReturn(callable);
    when(() => callable.call<Map<String, dynamic>>(any())).thenAnswer((_) async => result);
    when(() => result.data).thenReturn({'results': []});

    await tester.pumpWidget(
      MaterialApp(
        home: FoodPicker(
          uid: 'uid-1',
          searchService: searchService,
          onSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Nordic Curl Stew');
    await tester.pumpAndSettle();

    expect(find.textContaining('Add "Nordic Curl Stew"'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/nutrition/presentation/food_picker_test.dart`
Expected: FAIL — `food_picker.dart` doesn't exist.

- [ ] **Step 3: Implement FoodPicker**

```dart
// lib/features/nutrition/presentation/food_picker.dart
import 'package:flutter/material.dart';
import '../data/food_search_service.dart';
import '../domain/food_entry.dart';
import '../domain/food_search_result.dart';

class FoodPicker extends StatefulWidget {
  const FoodPicker({
    super.key,
    required this.uid,
    required this.searchService,
    required this.onSelected,
  });

  final String uid;
  final FoodSearchService searchService;
  final ValueChanged<FoodSearchResult> onSelected;

  @override
  State<FoodPicker> createState() => _FoodPickerState();
}

class _FoodPickerState extends State<FoodPicker> {
  final _controller = TextEditingController();
  List<FoodSearchResult> _results = [];

  /// Incremented per search; a response is only applied if it belongs to
  /// the most recent request, so a slow early query can't clobber a newer one.
  int _searchToken = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    final token = ++_searchToken;
    try {
      final results = await widget.searchService.search(widget.uid, query);
      if (!mounted || token != _searchToken) return;
      setState(() => _results = results);
    } catch (error) {
      debugPrint('Food search failed: $error');
    }
  }

  Future<void> _addCustom(String name) async {
    // A custom food's macros are entered on the dedicated add-custom form
    // this picker navigates to, not inline here, since the form needs
    // several numeric fields.
    final repository = widget.searchService.customFoodRepository;
    final macros = await Navigator.of(context).push<Map<String, double>>(
      MaterialPageRoute(builder: (_) => _AddCustomFoodForm(name: name)),
    );
    if (macros == null) return;
    final food = await repository.addCustom(
      widget.uid,
      name: name,
      caloriesPer100g: macros['calories']!,
      proteinPer100g: macros['protein']!,
      carbsPer100g: macros['carbs']!,
      fatPer100g: macros['fat']!,
    );
    widget.onSelected(FoodSearchResult(
      name: food.name,
      source: FoodSource.custom,
      caloriesPer100g: food.caloriesPer100g,
      proteinPer100g: food.proteinPer100g,
      carbsPer100g: food.carbsPer100g,
      fatPer100g: food.fatPer100g,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();

    return Material(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(labelText: 'Search foods'),
            onChanged: _search,
          ),
          Expanded(
            child: ListView(
              children: [
                for (final result in _results)
                  ListTile(
                    title: Text(result.name),
                    subtitle: Text('${result.caloriesPer100g.toStringAsFixed(0)} kcal/100g'),
                    onTap: () => widget.onSelected(result),
                  ),
                if (query.isNotEmpty)
                  ListTile(
                    title: Text('Add "$query"'),
                    onTap: () => _addCustom(query),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddCustomFoodForm extends StatefulWidget {
  const _AddCustomFoodForm({required this.name});

  final String name;

  @override
  State<_AddCustomFoodForm> createState() => _AddCustomFoodFormState();
}

class _AddCustomFoodFormState extends State<_AddCustomFoodForm> {
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  void _save() {
    final calories = double.tryParse(_caloriesController.text);
    final protein = double.tryParse(_proteinController.text);
    final carbs = double.tryParse(_carbsController.text);
    final fat = double.tryParse(_fatController.text);
    if (calories == null || protein == null || carbs == null || fat == null) return;
    Navigator.of(context).pop({
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add "${widget.name}"')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextField(
              controller: _caloriesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Calories per 100g'),
            ),
            TextField(
              controller: _proteinController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Protein (g) per 100g'),
            ),
            TextField(
              controller: _carbsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Carbs (g) per 100g'),
            ),
            TextField(
              controller: _fatController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Fat (g) per 100g'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
```

(`_addCustom` above uses `widget.searchService.customFoodRepository`, the getter Task 6 added to `FoodSearchService` for exactly this purpose — no separate `CustomFoodRepository` construction needed here.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/nutrition/presentation/food_picker_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Run analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 6: Commit**

```bash
git add lib/features/nutrition/presentation/food_picker.dart lib/features/nutrition/data/food_search_service.dart test/features/nutrition/presentation/food_picker_test.dart
git commit -m "Add FoodPicker widget with search and add-custom-food flow"
```

---

### Task 8: Log food screen (search mode + natural-language mode)

**Files:**
- Create: `lib/features/nutrition/presentation/log_food_screen.dart`
- Test: `test/features/nutrition/presentation/log_food_screen_test.dart`

**Interfaces:**
- Consumes: `FoodPicker` (Task 7), `NutritionRepository`, `MealType`, `FoodSource` (Task 1), `FoodSearchService`, `ParsedFoodItem` (Task 6), `GlassCard`/`PrimaryButton` (Phase 1).
- Produces: `LogFoodScreen({required String uid, required NutritionRepository nutritionRepository, required FoodSearchService searchService, required VoidCallback onSaved})` — consumed by Task 9's nutrition home screen (navigation target).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/nutrition/presentation/log_food_screen_test.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fitness_tracker/features/nutrition/data/custom_food_repository.dart';
import 'package:fitness_tracker/features/nutrition/data/food_search_service.dart';
import 'package:fitness_tracker/features/nutrition/data/nutrition_repository.dart';
import 'package:fitness_tracker/features/nutrition/presentation/log_food_screen.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult<T> extends Mock implements HttpsCallableResult<T> {}

void main() {
  testWidgets('search mode: pick a result, set grams, save logs the entry', (tester) async {
    final functions = MockFirebaseFunctions();
    final firestore = FakeFirebaseFirestore();
    final customFoodRepository = CustomFoodRepository(firestore: firestore);
    final searchService = FoodSearchService(functions: functions, customFoodRepository: customFoodRepository);
    final nutritionRepository = NutritionRepository(firestore: firestore);

    final callable = MockHttpsCallable();
    final result = MockHttpsCallableResult<Map<String, dynamic>>();
    when(() => functions.httpsCallable('searchFood')).thenReturn(callable);
    when(() => callable.call<Map<String, dynamic>>(any())).thenAnswer((_) async => result);
    when(() => result.data).thenReturn({
      'results': [
        {
          'name': 'White Rice',
          'source': 'usda',
          'caloriesPer100g': 130,
          'proteinPer100g': 2.7,
          'carbsPer100g': 28,
          'fatPer100g': 0.3,
        },
      ],
    });

    var saved = false;

    await tester.pumpWidget(
      MaterialApp(
        home: LogFoodScreen(
          uid: 'uid-1',
          nutritionRepository: nutritionRepository,
          searchService: searchService,
          onSaved: () => saved = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('foodSearchField')), 'rice');
    await tester.pumpAndSettle();
    await tester.tap(find.text('White Rice'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('quantityGramsField')), '200');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, isTrue);
    final entries = await nutritionRepository.listFoodLog('uid-1');
    expect(entries, hasLength(1));
    expect(entries.first.foodName, 'White Rice');
    expect(entries.first.quantityGrams, 200);
    // 130 kcal/100g scaled to 200g = 260.
    expect(entries.first.calories, 260);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/nutrition/presentation/log_food_screen_test.dart`
Expected: FAIL — `log_food_screen.dart` doesn't exist.

- [ ] **Step 3: Implement LogFoodScreen**

```dart
// lib/features/nutrition/presentation/log_food_screen.dart
import 'package:flutter/material.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/food_search_service.dart';
import '../data/nutrition_repository.dart';
import '../domain/food_entry.dart';
import '../domain/food_search_result.dart';
import 'food_picker.dart';

class LogFoodScreen extends StatefulWidget {
  const LogFoodScreen({
    super.key,
    required this.uid,
    required this.nutritionRepository,
    required this.searchService,
    required this.onSaved,
  });

  final String uid;
  final NutritionRepository nutritionRepository;
  final FoodSearchService searchService;
  final VoidCallback onSaved;

  @override
  State<LogFoodScreen> createState() => _LogFoodScreenState();
}

class _LogFoodScreenState extends State<LogFoodScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);
  final _quantityController = TextEditingController(text: '100');
  final _naturalLanguageController = TextEditingController();

  MealType _mealType = MealType.breakfast;
  FoodSearchResult? _selectedFood;
  List<ParsedFoodItem> _parsedItems = [];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _tabController.dispose();
    _quantityController.dispose();
    _naturalLanguageController.dispose();
    super.dispose();
  }

  void _openSearchPicker() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Search foods')),
          body: FoodPicker(
            uid: widget.uid,
            searchService: widget.searchService,
            onSelected: (result) {
              Navigator.of(context).pop();
              setState(() => _selectedFood = result);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _parseNaturalLanguage() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final items = await widget.searchService.parseText(_naturalLanguageController.text);
      if (!mounted) return;
      setState(() => _parsedItems = items);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not parse that. Try again or use search instead.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveSelectedFood() async {
    final food = _selectedFood;
    final grams = double.tryParse(_quantityController.text);
    if (food == null || grams == null || grams <= 0) return;

    setState(() => _saving = true);
    final scale = grams / 100;
    widget.nutritionRepository
        .logFood(
          uid: widget.uid,
          date: DateTime.now(),
          mealType: _mealType,
          foodName: food.name,
          quantityGrams: grams,
          calories: food.caloriesPer100g * scale,
          proteinG: food.proteinPer100g * scale,
          carbsG: food.carbsPer100g * scale,
          fatG: food.fatPer100g * scale,
          source: food.source,
        )
        .then((_) {}, onError: (Object error) => debugPrint('Failed to log food: $error'));
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved();
  }

  Future<void> _saveParsedItems() async {
    setState(() => _saving = true);
    for (final item in _parsedItems) {
      FoodSearchResult resolved;
      try {
        final matches = await widget.searchService.search(widget.uid, item.foodName);
        resolved = matches.isNotEmpty
            ? matches.first
            : await widget.searchService.estimateNutrition(item.foodName);
      } catch (_) {
        resolved = await widget.searchService.estimateNutrition(item.foodName);
      }
      final scale = item.estimatedQuantityGrams / 100;
      // Fire-and-handle-errors rather than awaited: Firestore's offline
      // persistence updates the local cache immediately but the returned
      // Future doesn't resolve until the server acks, which never happens
      // offline — awaiting it here would hang this loop (and the UI)
      // indefinitely with no connectivity. The resolve-macros calls above
      // are Cloud Function calls and inherently require connectivity
      // already, so only this final write needs the fire-and-forget
      // treatment.
      widget.nutritionRepository
          .logFood(
            uid: widget.uid,
            date: DateTime.now(),
            mealType: _mealType,
            foodName: item.foodName,
            quantityGrams: item.estimatedQuantityGrams,
            calories: resolved.caloriesPer100g * scale,
            proteinG: resolved.proteinPer100g * scale,
            carbsG: resolved.carbsPer100g * scale,
            fatG: resolved.fatPer100g * scale,
            source: resolved.source,
          )
          .then((_) {}, onError: (Object error) => debugPrint('Failed to log food: $error'));
    }
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log food'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Search'), Tab(text: 'Describe')],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildSearchTab(),
            _buildNaturalLanguageTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        DropdownButton<MealType>(
          value: _mealType,
          items: MealType.values
              .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
              .toList(),
          onChanged: (m) => setState(() => _mealType = m ?? _mealType),
        ),
        const SizedBox(height: 16),
        if (_selectedFood != null)
          GlassCard(child: Text(_selectedFood!.name))
        else
          const SizedBox.shrink(),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: _openSearchPicker, child: const Text('Search for food')),
        const SizedBox(height: 16),
        TextField(
          key: const Key('quantityGramsField'),
          controller: _quantityController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantity (grams)'),
        ),
        const SizedBox(height: 24),
        _saving
            ? const Center(child: CircularProgressIndicator())
            : PrimaryButton(
                label: 'Save',
                onPressed: _selectedFood == null ? null : _saveSelectedFood,
              ),
      ],
    );
  }

  Widget _buildNaturalLanguageTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        DropdownButton<MealType>(
          value: _mealType,
          items: MealType.values
              .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
              .toList(),
          onChanged: (m) => setState(() => _mealType = m ?? _mealType),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _naturalLanguageController,
          decoration: const InputDecoration(labelText: 'Describe what you ate'),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: _parseNaturalLanguage, child: const Text('Parse')),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
        const SizedBox(height: 16),
        for (final item in _parsedItems)
          GlassCard(
            child: Text('${item.foodName} — ${item.estimatedQuantityGrams.toStringAsFixed(0)}g'),
          ),
        const SizedBox(height: 24),
        _saving
            ? const Center(child: CircularProgressIndicator())
            : PrimaryButton(
                label: 'Save all',
                onPressed: _parsedItems.isEmpty ? null : _saveParsedItems,
              ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/nutrition/presentation/log_food_screen_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Run analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 6: Commit**

```bash
git add lib/features/nutrition/presentation/log_food_screen.dart test/features/nutrition/presentation/log_food_screen_test.dart
git commit -m "Add LogFoodScreen with search and natural-language logging modes"
```

---

### Task 9: Nutrition home/daily-summary screen, router, and dashboard wiring

**Files:**
- Create: `lib/features/nutrition/presentation/nutrition_home_screen.dart`
- Create: `lib/features/nutrition/presentation/nutrition_providers.dart`
- Test: `test/features/nutrition/presentation/nutrition_home_screen_test.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/dashboard/presentation/dashboard_screen.dart`

**Interfaces:**
- Consumes: `NutritionRepository`, `FoodEntry`, `MealType`, `NutritionGoals` (Task 1), `LogFoodScreen` (Task 8), `GlassCard`/`ProgressRing`/`AppColors` (Phase 1).
- Produces: `NutritionHomeScreen({required String uid, required NutritionRepository nutritionRepository, required FoodSearchService searchService})` — the entry point reached from the dashboard, matching Phase 2's `/workouts` route pattern exactly (`push`, not `go`, so the back button works).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/nutrition/presentation/nutrition_home_screen_test.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fitness_tracker/features/nutrition/data/custom_food_repository.dart';
import 'package:fitness_tracker/features/nutrition/data/food_search_service.dart';
import 'package:fitness_tracker/features/nutrition/data/nutrition_repository.dart';
import 'package:fitness_tracker/features/nutrition/domain/food_entry.dart';
import 'package:fitness_tracker/features/nutrition/presentation/nutrition_home_screen.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

void main() {
  testWidgets('shows today\'s food log grouped by meal with a day total', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final nutritionRepository = NutritionRepository(firestore: firestore);
    final searchService = FoodSearchService(
      functions: MockFirebaseFunctions(),
      customFoodRepository: CustomFoodRepository(firestore: firestore),
    );

    final today = DateTime.now();
    await nutritionRepository.logFood(
      uid: 'uid-1', date: today, mealType: MealType.breakfast,
      foodName: 'Idli', quantityGrams: 150, calories: 195, proteinG: 6,
      carbsG: 40, fatG: 1.5, source: FoodSource.custom);

    await tester.pumpWidget(
      MaterialApp(
        home: NutritionHomeScreen(
          uid: 'uid-1',
          nutritionRepository: nutritionRepository,
          searchService: searchService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Idli'), findsOneWidget);
    expect(find.textContaining('195'), findsWidgets);
  });

  testWidgets('shows an empty state with no entries today', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final nutritionRepository = NutritionRepository(firestore: firestore);
    final searchService = FoodSearchService(
      functions: MockFirebaseFunctions(),
      customFoodRepository: CustomFoodRepository(firestore: firestore),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NutritionHomeScreen(
          uid: 'uid-1',
          nutritionRepository: nutritionRepository,
          searchService: searchService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No food logged yet today.'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/nutrition/presentation/nutrition_home_screen_test.dart`
Expected: FAIL — `nutrition_home_screen.dart` doesn't exist.

- [ ] **Step 3: Implement NutritionHomeScreen**

```dart
// lib/features/nutrition/presentation/nutrition_home_screen.dart
import 'package:flutter/material.dart';
import '../../../core/widgets/glass_card.dart';
import '../data/food_search_service.dart';
import '../data/nutrition_repository.dart';
import '../domain/food_entry.dart';
import 'log_food_screen.dart';

class NutritionHomeScreen extends StatefulWidget {
  const NutritionHomeScreen({
    super.key,
    required this.uid,
    required this.nutritionRepository,
    required this.searchService,
  });

  final String uid;
  final NutritionRepository nutritionRepository;
  final FoodSearchService searchService;

  @override
  State<NutritionHomeScreen> createState() => _NutritionHomeScreenState();
}

class _NutritionHomeScreenState extends State<NutritionHomeScreen> {
  DateTime _selectedDate = DateTime.now();
  late Future<List<FoodEntry>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _entriesFuture = widget.nutritionRepository.listFoodLog(widget.uid);
    });
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _openLogFood() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LogFoodScreen(
          uid: widget.uid,
          nutritionRepository: widget.nutritionRepository,
          searchService: widget.searchService,
          onSaved: () {
            Navigator.of(context).pop();
            _refresh();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() =>
                _selectedDate = _selectedDate.subtract(const Duration(days: 1))),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() =>
                _selectedDate = _selectedDate.add(const Duration(days: 1))),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Log food',
        onPressed: _openLogFood,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FutureBuilder<List<FoodEntry>>(
            future: _entriesFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final entries = snapshot.data!
                  .where((e) => _isSameDay(e.date, _selectedDate))
                  .toList();
              if (entries.isEmpty) {
                return const Center(child: Text('No food logged yet today.'));
              }

              final totalCalories = entries.fold<double>(0, (sum, e) => sum + e.calories);

              return ListView(
                children: [
                  GlassCard(child: Text('Total: ${totalCalories.toStringAsFixed(0)} kcal')),
                  const SizedBox(height: 16),
                  for (final mealType in MealType.values) ...[
                    for (final entry in entries.where((e) => e.mealType == mealType))
                      GlassCard(
                        child: ListTile(
                          title: Text(entry.foodName),
                          subtitle: Text(
                            '${mealType.name} · ${entry.quantityGrams.toStringAsFixed(0)}g · ${entry.calories.toStringAsFixed(0)} kcal',
                          ),
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Implement nutrition_providers.dart**

```dart
// lib/features/nutrition/presentation/nutrition_providers.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/custom_food_repository.dart';
import '../data/food_search_service.dart';
import '../data/nutrition_repository.dart';

final nutritionRepositoryProvider = Provider<NutritionRepository>((ref) {
  return NutritionRepository(firestore: ref.watch(firestoreProvider));
});

final customFoodRepositoryProvider = Provider<CustomFoodRepository>((ref) {
  return CustomFoodRepository(firestore: ref.watch(firestoreProvider));
});

final foodSearchServiceProvider = Provider<FoodSearchService>((ref) {
  return FoodSearchService(
    functions: FirebaseFunctions.instance,
    customFoodRepository: ref.watch(customFoodRepositoryProvider),
  );
});
```

- [ ] **Step 5: Wire the `/nutrition` route into app_router.dart**

Modify `lib/core/router/app_router.dart`: add the import and a new `GoRoute`, following the exact `/workouts` pattern (read `uid` via the captured `ref`, construct dependencies via `ref.read`):

```dart
// Add these imports at the top:
import '../../features/nutrition/presentation/nutrition_home_screen.dart';
import '../../features/nutrition/presentation/nutrition_providers.dart';
```

```dart
// Add this route inside the `routes: [...]` list, alongside '/workouts':
      GoRoute(
        path: '/nutrition',
        builder: (context, state) {
          final uid = ref.read(firebaseAuthProvider).currentUser!.uid;
          return NutritionHomeScreen(
            uid: uid,
            nutritionRepository: ref.read(nutritionRepositoryProvider),
            searchService: ref.read(foodSearchServiceProvider),
          );
        },
      ),
```

- [ ] **Step 6: Wire a Nutrition entry point into dashboard_screen.dart**

Modify `lib/features/dashboard/presentation/dashboard_screen.dart`: replace the placeholder text `'Nutrition and habits land here in Phase 3+.'` inside the "Today" `GlassCard` with a `PrimaryButton` that pushes `/nutrition`, matching the "Workouts" card's button pattern exactly. No new imports are needed — `go_router` and `primary_button.dart` are already imported in this file for the existing "Workouts" card.

```dart
// Replace:
                    const Text('Nutrition and habits land here in Phase 3+.'),
// With:
                    const Text('Log meals and track calories/macros against your goals.'),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Open nutrition',
                      onPressed: () => GoRouter.of(context).push('/nutrition'),
                    ),
```

Note: the "Today" card's existing `ProgressRing` (showing a hardcoded "0 kcal") is left as-is — it is not wired to real data in this task. The working, live-data progress ring is added inside `NutritionHomeScreen` itself in Task 11. Wiring the dashboard's own ring to real nutrition data is out of scope for this phase; it would need a dashboard-level data fetch this plan doesn't otherwise require, and the dashboard already has a working navigation path to the real numbers via the new "Open nutrition" button.

- [ ] **Step 7: Run test to verify it passes**

Run: `flutter test test/features/nutrition/presentation/nutrition_home_screen_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 8: Run the full test suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: all tests pass, "No issues found!"

- [ ] **Step 9: Commit**

```bash
git add lib/features/nutrition/presentation/nutrition_home_screen.dart lib/features/nutrition/presentation/nutrition_providers.dart lib/core/router/app_router.dart lib/features/dashboard/presentation/dashboard_screen.dart test/features/nutrition/presentation/nutrition_home_screen_test.dart
git commit -m "Add Nutrition home screen, wire router and dashboard entry point"
```

---

### Task 10: Nutrition goals screen

**Files:**
- Create: `lib/features/nutrition/presentation/nutrition_goals_screen.dart`
- Test: `test/features/nutrition/presentation/nutrition_goals_screen_test.dart`
- Modify: `lib/features/nutrition/presentation/nutrition_home_screen.dart`

**Interfaces:**
- Consumes: `NutritionRepository`, `NutritionGoals` (Task 1), `GlassCard`/`PrimaryButton` (Phase 1).
- Produces: `NutritionGoalsScreen({required String uid, required NutritionRepository nutritionRepository, required VoidCallback onSaved})` — consumed by Task 9's home screen (extending it with a settings action, wired in this task).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/nutrition/presentation/nutrition_goals_screen_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/nutrition/data/nutrition_repository.dart';
import 'package:fitness_tracker/features/nutrition/presentation/nutrition_goals_screen.dart';

void main() {
  testWidgets('saving valid goals writes them and calls onSaved', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = NutritionRepository(firestore: firestore);

    var saved = false;

    await tester.pumpWidget(
      MaterialApp(
        home: NutritionGoalsScreen(
          uid: 'uid-1',
          nutritionRepository: repository,
          onSaved: () => saved = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('caloriesField')), '2000');
    await tester.enterText(find.byKey(const Key('proteinField')), '150');
    await tester.enterText(find.byKey(const Key('carbsField')), '200');
    await tester.enterText(find.byKey(const Key('fatField')), '60');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save goals'));
    await tester.pumpAndSettle();

    expect(saved, isTrue);
    final goals = await repository.getGoals('uid-1');
    expect(goals!.dailyCalories, 2000);
    expect(goals.proteinG, 150);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/nutrition/presentation/nutrition_goals_screen_test.dart`
Expected: FAIL — `nutrition_goals_screen.dart` doesn't exist.

- [ ] **Step 3: Implement NutritionGoalsScreen**

```dart
// lib/features/nutrition/presentation/nutrition_goals_screen.dart
import 'package:flutter/material.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/nutrition_repository.dart';
import '../domain/food_entry.dart';

class NutritionGoalsScreen extends StatefulWidget {
  const NutritionGoalsScreen({
    super.key,
    required this.uid,
    required this.nutritionRepository,
    required this.onSaved,
  });

  final String uid;
  final NutritionRepository nutritionRepository;
  final VoidCallback onSaved;

  @override
  State<NutritionGoalsScreen> createState() => _NutritionGoalsScreenState();
}

class _NutritionGoalsScreenState extends State<NutritionGoalsScreen> {
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    widget.nutritionRepository.getGoals(widget.uid).then((goals) {
      if (!mounted || goals == null) return;
      _caloriesController.text = goals.dailyCalories.toStringAsFixed(0);
      _proteinController.text = goals.proteinG.toStringAsFixed(0);
      _carbsController.text = goals.carbsG.toStringAsFixed(0);
      _fatController.text = goals.fatG.toStringAsFixed(0);
    });
  }

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final calories = double.tryParse(_caloriesController.text);
    final protein = double.tryParse(_proteinController.text);
    final carbs = double.tryParse(_carbsController.text);
    final fat = double.tryParse(_fatController.text);
    if (calories == null || protein == null || carbs == null || fat == null) return;

    setState(() => _saving = true);
    // Fire-and-handle-errors, not awaited: Firestore's offline persistence
    // updates the local cache immediately but the returned Future doesn't
    // resolve until the server acks, which never happens offline — awaiting
    // it here would leave this screen spinning indefinitely with no
    // connectivity.
    widget.nutritionRepository
        .setGoals(
          widget.uid,
          NutritionGoals(dailyCalories: calories, proteinG: protein, carbsG: carbs, fatG: fat),
        )
        .then((_) {}, onError: (Object error) => debugPrint('Failed to save goals: $error'));
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nutrition goals')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const Key('caloriesField'),
                  controller: _caloriesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Daily calories'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('proteinField'),
                  controller: _proteinController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Protein (g)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('carbsField'),
                  controller: _carbsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Carbs (g)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('fatField'),
                  controller: _fatController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Fat (g)'),
                ),
                const SizedBox(height: 24),
                _saving
                    ? const Center(child: CircularProgressIndicator())
                    : PrimaryButton(label: 'Save goals', onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Wire a goals action into NutritionHomeScreen**

Modify `lib/features/nutrition/presentation/nutrition_home_screen.dart`: add an import and an `IconButton` in the `AppBar.actions` list (alongside the existing chevron-left/chevron-right buttons) that pushes `NutritionGoalsScreen`, refreshing on return:

```dart
// Add this import at the top:
import 'nutrition_goals_screen.dart';
```

```dart
// Add this to the AppBar's `actions` list, before the chevron buttons:
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Goals',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NutritionGoalsScreen(
                    uid: widget.uid,
                    nutritionRepository: widget.nutritionRepository,
                    onSaved: () => Navigator.of(context).pop(),
                  ),
                ),
              );
              _refresh();
            },
          ),
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/nutrition/presentation/nutrition_goals_screen_test.dart`
Expected: PASS (1 test).

- [ ] **Step 6: Run the full test suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: all tests pass, "No issues found!"

- [ ] **Step 7: Commit**

```bash
git add lib/features/nutrition/presentation/nutrition_goals_screen.dart lib/features/nutrition/presentation/nutrition_home_screen.dart test/features/nutrition/presentation/nutrition_goals_screen_test.dart
git commit -m "Add NutritionGoalsScreen and wire it into the nutrition home screen"
```

---

### Task 11: Food log entry detail/edit screen, goal progress display, and Cloud Functions secrets setup

**Files:**
- Create: `lib/features/nutrition/presentation/food_entry_detail_screen.dart`
- Modify: `lib/features/nutrition/presentation/nutrition_home_screen.dart`

**Interfaces:**
- Consumes: `FoodEntry`, `NutritionRepository`, `MealType` (Task 1), `NutritionGoals` (Task 1), `GlassCard`/`PrimaryButton`/`ProgressRing`/`AppColors` (Phase 1).
- Produces: `FoodEntryDetailScreen({required String uid, required FoodEntry entry, required NutritionRepository nutritionRepository, required VoidCallback onChanged})` — the final piece; nothing downstream in this plan consumes it. Also adds goal-progress rings to the home screen, extending Task 9's list with a tap target reaching this screen.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/nutrition/presentation/food_entry_detail_screen_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/nutrition/data/nutrition_repository.dart';
import 'package:fitness_tracker/features/nutrition/domain/food_entry.dart';
import 'package:fitness_tracker/features/nutrition/presentation/food_entry_detail_screen.dart';

void main() {
  testWidgets('editing quantity recomputes macros and saves', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = NutritionRepository(firestore: firestore);

    final id = await repository.logFood(
      uid: 'uid-1', date: DateTime(2026, 8, 1), mealType: MealType.lunch,
      foodName: 'Rice', quantityGrams: 100, calories: 130, proteinG: 2.7,
      carbsG: 28, fatG: 0.3, source: FoodSource.usda);
    final entry = (await repository.listFoodLog('uid-1')).first;

    var changed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: FoodEntryDetailScreen(
          uid: 'uid-1',
          entry: entry,
          nutritionRepository: repository,
          onChanged: () => changed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('quantityGramsField')), '200');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(changed, isTrue);
    final updated = (await repository.listFoodLog('uid-1')).firstWhere((e) => e.id == id);
    expect(updated.quantityGrams, 200);
    // Per-gram rate preserved: 130/100 * 200 = 260.
    expect(updated.calories, 260);
  });

  testWidgets('delete removes the entry', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = NutritionRepository(firestore: firestore);

    await repository.logFood(
      uid: 'uid-1', date: DateTime(2026, 8, 1), mealType: MealType.snack,
      foodName: 'to delete', quantityGrams: 50, calories: 50, proteinG: 1,
      carbsG: 1, fatG: 1, source: FoodSource.custom);
    final entry = (await repository.listFoodLog('uid-1')).first;

    var changed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: FoodEntryDetailScreen(
          uid: 'uid-1',
          entry: entry,
          nutritionRepository: repository,
          onChanged: () => changed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    expect(changed, isTrue);
    expect(await repository.listFoodLog('uid-1'), isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/nutrition/presentation/food_entry_detail_screen_test.dart`
Expected: FAIL — `food_entry_detail_screen.dart` doesn't exist.

- [ ] **Step 3: Implement FoodEntryDetailScreen**

```dart
// lib/features/nutrition/presentation/food_entry_detail_screen.dart
import 'package:flutter/material.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/nutrition_repository.dart';
import '../domain/food_entry.dart';

class FoodEntryDetailScreen extends StatefulWidget {
  const FoodEntryDetailScreen({
    super.key,
    required this.uid,
    required this.entry,
    required this.nutritionRepository,
    required this.onChanged,
  });

  final String uid;
  final FoodEntry entry;
  final NutritionRepository nutritionRepository;
  final VoidCallback onChanged;

  @override
  State<FoodEntryDetailScreen> createState() => _FoodEntryDetailScreenState();
}

class _FoodEntryDetailScreenState extends State<FoodEntryDetailScreen> {
  late final _quantityController =
      TextEditingController(text: widget.entry.quantityGrams.toStringAsFixed(0));
  late MealType _mealType = widget.entry.mealType;

  /// Per-gram nutrition rate derived from the entry as originally logged,
  /// so editing quantity rescales macros consistently without needing to
  /// re-query the original food source.
  double get _caloriesPerGram => widget.entry.calories / widget.entry.quantityGrams;
  double get _proteinPerGram => widget.entry.proteinG / widget.entry.quantityGrams;
  double get _carbsPerGram => widget.entry.carbsG / widget.entry.quantityGrams;
  double get _fatPerGram => widget.entry.fatG / widget.entry.quantityGrams;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final grams = double.tryParse(_quantityController.text);
    if (grams == null || grams <= 0) return;

    widget.nutritionRepository
        .updateFoodEntry(
          uid: widget.uid,
          entryId: widget.entry.id,
          mealType: _mealType,
          quantityGrams: grams,
          calories: _caloriesPerGram * grams,
          proteinG: _proteinPerGram * grams,
          carbsG: _carbsPerGram * grams,
          fatG: _fatPerGram * grams,
        )
        .then((_) {}, onError: (Object error) => debugPrint('Failed to update food entry: $error'));
    if (!mounted) return;
    widget.onChanged();
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await widget.nutritionRepository.deleteFoodEntry(widget.uid, widget.entry.id);
    if (!mounted) return;
    widget.onChanged();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry.foodName),
        actions: [IconButton(icon: const Icon(Icons.delete), onPressed: _delete)],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButton<MealType>(
                  value: _mealType,
                  items: MealType.values
                      .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
                      .toList(),
                  onChanged: (m) => setState(() => _mealType = m ?? _mealType),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('quantityGramsField'),
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity (grams)'),
                ),
                const SizedBox(height: 24),
                PrimaryButton(label: 'Save changes', onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Wire navigation from NutritionHomeScreen's list to FoodEntryDetailScreen, and add goal-progress rings**

Modify `lib/features/nutrition/presentation/nutrition_home_screen.dart`:

Add imports:
```dart
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/progress_ring.dart';
import 'food_entry_detail_screen.dart';
```

Add a `_goalsFuture` field alongside the existing `_entriesFuture` field, and fetch it in `_refresh()`:

```dart
// Change:
  late Future<List<FoodEntry>> _entriesFuture;
// To:
  late Future<List<FoodEntry>> _entriesFuture;
  late Future<NutritionGoals?> _goalsFuture;
```

```dart
// Change:
  void _refresh() {
    setState(() {
      _entriesFuture = widget.nutritionRepository.listFoodLog(widget.uid);
    });
  }
// To:
  void _refresh() {
    setState(() {
      _entriesFuture = widget.nutritionRepository.listFoodLog(widget.uid);
      _goalsFuture = widget.nutritionRepository.getGoals(widget.uid);
    });
  }
```

Change the `GlassCard(child: ListTile(...))` for each entry to wrap the `ListTile` with `onTap`:

```dart
                      GlassCard(
                        child: ListTile(
                          title: Text(entry.foodName),
                          subtitle: Text(
                            '${mealType.name} · ${entry.quantityGrams.toStringAsFixed(0)}g · ${entry.calories.toStringAsFixed(0)} kcal',
                          ),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FoodEntryDetailScreen(
                                  uid: widget.uid,
                                  entry: entry,
                                  nutritionRepository: widget.nutritionRepository,
                                  onChanged: _refresh,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
```

Add a goal-progress ring above the entry list, using `_goalsFuture` (already fetched in `_refresh`) alongside the existing calorie total — replace the `GlassCard(child: Text('Total: ...'))` line with:

```dart
                  FutureBuilder<NutritionGoals?>(
                    future: _goalsFuture,
                    builder: (context, goalsSnapshot) {
                      final goals = goalsSnapshot.data;
                      final progress = goals == null || goals.dailyCalories == 0
                          ? 0.0
                          : (totalCalories / goals.dailyCalories).clamp(0.0, 1.0);
                      return GlassCard(
                        child: Column(
                          children: [
                            ProgressRing(
                              progress: progress,
                              color: AppColors.accentGreen,
                              center: Text('${totalCalories.toStringAsFixed(0)} kcal'),
                            ),
                            if (goals != null) ...[
                              const SizedBox(height: 8),
                              Text('Goal: ${goals.dailyCalories.toStringAsFixed(0)} kcal'),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
```

- [ ] **Step 5: Run the full test suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: all tests pass, "No issues found!"

- [ ] **Step 6: Set the API secrets as Cloud Functions environment config**

This step requires free API credentials the user must obtain first: a USDA FoodData Central API key (https://fdc.nal.usda.gov/api-key-signup — free, instant), a Nutritionix App ID + App Key (https://developer.nutritionix.com — free tier signup), a Groq API key (https://console.groq.com/keys — free, no card), and an NVIDIA NIM API key (https://build.nvidia.com — free tier). If these haven't been provided yet, STOP here and report NEEDS_CONTEXT — do not fabricate placeholder values and deploy with them.

```bash
firebase functions:secrets:set USDA_API_KEY
firebase functions:secrets:set NUTRITIONIX_APP_ID
firebase functions:secrets:set NUTRITIONIX_APP_KEY
firebase functions:secrets:set GROQ_API_KEY
firebase functions:secrets:set NVIDIA_NIM_API_KEY
```

- [ ] **Step 7: Deploy functions**

```bash
firebase deploy --only functions
```

Expected: deploys successfully.

- [ ] **Step 8: Manual verification**

1. Run the app (`flutter run`), sign in, navigate to the dashboard, tap "Open nutrition."
2. Set daily goals via the flag icon.
3. Log a food via Search mode (e.g. search "rice", pick a result, set grams, save) — confirm it appears in today's list and the progress ring updates.
4. Log food via Describe mode (e.g. "2 idlis and a cup of sambar") — confirm parsed items appear for review and save correctly, falling through to LLM-estimated nutrition for anything the food-source search doesn't match.
5. Tap a logged entry, change its quantity, save — confirm macros rescale correctly.
6. Delete an entry — confirm it's removed and the day total updates.

- [ ] **Step 9: Commit**

```bash
git add lib/features/nutrition/presentation/food_entry_detail_screen.dart lib/features/nutrition/presentation/nutrition_home_screen.dart test/features/nutrition/presentation/food_entry_detail_screen_test.dart
git commit -m "Add FoodEntryDetailScreen and goal-progress ring on the nutrition home screen"
```

---

## Phase 3 Exit Criteria

- `flutter analyze` clean and `flutter test` passes across the whole suite; `cd functions && npx tsc --noEmit && npm test` passes for the Cloud Functions.
- A user can set daily calorie/macro goals, log food via search (USDA/Open Food Facts/Nutritionix/custom) with a grams-based quantity, and via natural-language description (parsed by Groq/NVIDIA NIM, falling back to LLM-estimated nutrition for unmatched items).
- The daily view shows food grouped by meal type with per-entry and day-total calories/macros, and progress against goals.
- Any logged entry can be edited (quantity/meal type, with macros correctly rescaled) or deleted.
- All external API keys (USDA, Nutritionix, Groq, NVIDIA NIM) exist only as Cloud Functions secrets, never in the Flutter app or committed to git.
- The Nutrition entry point is reachable from the dashboard via `push` (not `go`), so back navigation works — this was a real bug caught in Phase 2's final review and must not recur.
