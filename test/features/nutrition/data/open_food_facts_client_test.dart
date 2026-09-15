import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:fitness_tracker/features/nutrition/data/open_food_facts_client.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MockHttpClient client;
  late OpenFoodFactsClient offClient;

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() {
    client = MockHttpClient();
    offClient = OpenFoodFactsClient(client: client);
  });

  test('lookupBarcode returns a ScannedFood for a found product', () async {
    when(() => client.get(any())).thenAnswer(
      (_) async => http.Response(
        jsonEncode({
          'status': 1,
          'product': {
            'product_name': 'Amul Dark Chocolate',
            'nutriments': {
              'energy-kcal_100g': 540,
              'proteins_100g': 6.5,
              'carbohydrates_100g': 52.0,
              'fat_100g': 32.0,
            },
          },
        }),
        200,
      ),
    );

    final food = await offClient.lookupBarcode('8901030826524');

    expect(food, isNotNull);
    expect(food!.name, 'Amul Dark Chocolate');
    expect(food.barcode, '8901030826524');
    expect(food.caloriesPer100g, 540);
    expect(food.proteinPer100g, 6.5);
    expect(food.carbsPer100g, 52.0);
    expect(food.fatPer100g, 32.0);
  });

  test('lookupBarcode returns null when the product is not found (status 0)', () async {
    when(() => client.get(any())).thenAnswer(
      (_) async => http.Response(jsonEncode({'status': 0}), 200),
    );

    final food = await offClient.lookupBarcode('0000000000000');

    expect(food, isNull);
  });

  test('lookupBarcode returns null when the HTTP call fails', () async {
    when(() => client.get(any())).thenAnswer(
      (_) async => http.Response('Server error', 500),
    );

    final food = await offClient.lookupBarcode('123');

    expect(food, isNull);
  });

  test('lookupBarcode returns null when nutriments are missing', () async {
    when(() => client.get(any())).thenAnswer(
      (_) async => http.Response(
        jsonEncode({
          'status': 1,
          'product': {'product_name': 'Mystery item'},
        }),
        200,
      ),
    );

    final food = await offClient.lookupBarcode('123');

    expect(food, isNull);
  });
}
