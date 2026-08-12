import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';

/// Parsing is checked against payloads copied verbatim from the live Karahi
/// Point seed (`GET /restaurant/items`, `/items/:id`, `/categories`) rather than
/// from shapes invented here, so a backend change shows up as a failing test.
void main() {
  group('MenuItem from GET /restaurant/items', () {
    // Verbatim from the seed.
    const beefNihari = '''
    {
      "id": "0b47916e-651e-412b-a61c-fc771c6b6eec",
      "categoryId": "cd43f73b-11bd-4e12-9e9d-9707329b2b64",
      "category": "Curries",
      "productId": null,
      "sku": "NIH-01",
      "barcode": null,
      "name": "Beef Nihari",
      "basePrice": {"amountMinor": 115000, "currency": "PKR"},
      "effectivePrice": {"amountMinor": 115000, "currency": "PKR"},
      "currency": "PKR",
      "taxBp": 1600,
      "prepMinutes": 12,
      "stationKey": "HOT_KITCHEN",
      "isCombo": false,
      "imageKey": "https://www.themealdb.com/images/media/meals/uttupv1511815050.jpg",
      "available": true,
      "status": "ACTIVE"
    }''';

    test('reads the fields the menu grid renders', () {
      final item = MenuItem.fromJson(jsonDecode(beefNihari));

      expect(item.name, 'Beef Nihari');
      expect(item.price, const Money(115000, 'PKR'));
      expect(item.categoryName, 'Curries');
      expect(item.taxBp, 1600);
      expect(item.stationKey, 'HOT_KITCHEN');
      expect(item.prepMinutes, 12);
      expect(item.isOrderable, isTrue);
    });

    test('prices at the branch-effective price, not the base price', () {
      final json = jsonDecode(beefNihari) as Map<String, dynamic>;
      json['effectivePrice'] = {'amountMinor': 99000, 'currency': 'PKR'};

      expect(MenuItem.fromJson(json).price.minor, 99000,
          reason: 'a per-branch override is what this outlet charges');
    });

    test('an uncategorised item parses — the seed has one', () {
      // "Biryani" in the seed: no category, and no tax override.
      final item = MenuItem.fromJson(jsonDecode('''
        {
          "id": "70b787fe-f2ee-480e-b6f6-9a7a50efe725",
          "categoryId": null, "category": null, "sku": "KAR-01",
          "name": "Biryani",
          "basePrice": {"amountMinor": 40000, "currency": "PKR"},
          "effectivePrice": {"amountMinor": 40000, "currency": "PKR"},
          "currency": "PKR", "taxBp": null, "prepMinutes": 10,
          "stationKey": "Kitchen", "isCombo": false, "imageKey": null,
          "available": true, "status": "ACTIVE"
        }'''));

      expect(item.categoryId, isNull);
      expect(item.taxBp, isNull);
      expect(item.resolvedTaxBp(1600), 1600,
          reason: 'null is "use the branch default", not "zero-rated"');
      expect(item.imageUrl, isNull);
    });

    test('an unavailable or non-ACTIVE item is not orderable', () {
      final json = jsonDecode(beefNihari) as Map<String, dynamic>;

      expect(MenuItem.fromJson({...json, 'available': false}).isOrderable,
          isFalse);
      expect(MenuItem.fromJson({...json, 'status': 'SOLD_OUT'}).isOrderable,
          isFalse,
          reason: 'the server rejects it with 422 at add-item time');
    });

    test('an imageKey that is a storage key rather than a URL is ignored', () {
      final json = jsonDecode(beefNihari) as Map<String, dynamic>;
      json['imageKey'] = 'menu/nihari.jpg';

      expect(MenuItem.fromJson(json).imageUrl, isNull,
          reason: 'a broken image tile is worse than no image');
    });
  });

  group('MenuItemDetail from GET /restaurant/items/:id', () {
    test('an item with no modifier groups needs no configuring', () {
      final detail = MenuItemDetail.fromJson(jsonDecode('''
        {
          "id": "0b47916e-651e-412b-a61c-fc771c6b6eec",
          "description": null, "calories": null,
          "allergens": [], "tags": [],
          "modifierGroups": [], "comboComponents": []
        }'''));

      expect(detail.needsConfiguration, isFalse);
      expect(detail.allergens, isEmpty);
    });

    test('groups come back in the designer\'s order', () {
      final detail = MenuItemDetail.fromJson(jsonDecode('''
        {
          "id": "i1", "description": "Slow-cooked overnight",
          "allergens": ["dairy"], "tags": ["spicy"], "calories": 720,
          "modifierGroups": [
            {"id": "g2", "name": "Add-ons", "minSelect": 0, "maxSelect": 3,
             "required": false, "sortOrder": 2},
            {"id": "g1", "name": "Spice level", "minSelect": 1, "maxSelect": 1,
             "required": true, "sortOrder": 1}
          ],
          "comboComponents": []
        }'''));

      expect(detail.modifierGroups.map((g) => g.id), ['g1', 'g2']);
      expect(detail.needsConfiguration, isTrue);
      expect(detail.allergens, ['dairy']);
      expect(detail.calories, 720);
    });
  });

  group('ModifierGroup from GET /restaurant/modifier-groups/:id', () {
    // No modifier groups exist in the seed, so this shape is read from
    // menu.service.ts getModifierGroupInTx rather than from live data.
    const group = '''
    {
      "id": "g1", "name": "Spice level", "minSelect": 1, "maxSelect": 1,
      "required": true, "sortOrder": 0,
      "modifiers": [
        {"id": "m1", "name": "Mild", "priceDelta": {"amountMinor": 0, "currency": "PKR"},
         "productId": null, "sortOrder": 0, "available": true},
        {"id": "m2", "name": "Extra hot", "priceDelta": {"amountMinor": 5000, "currency": "PKR"},
         "productId": null, "sortOrder": 1, "available": false}
      ]
    }''';

    test('reads the rules and the choices', () {
      final parsed = ModifierGroup.fromJson(jsonDecode(group));

      expect(parsed.name, 'Spice level');
      expect(parsed.required, isTrue);
      expect(parsed.maxSelect, 1);
      expect(parsed.modifiers, hasLength(2));
      expect(parsed.modifiers.last.priceDelta, const Money(5000, 'PKR'));
    });

    test('an unavailable choice is not offered', () {
      final parsed = ModifierGroup.fromJson(jsonDecode(group));

      expect(parsed.selectable.map((m) => m.id), ['m1'],
          reason: 'the server rejects an unavailable modifier with 422');
    });

    test('a required group demands a choice even when minSelect is 0', () {
      final json = jsonDecode(group) as Map<String, dynamic>;
      json['minSelect'] = 0;

      expect(ModifierGroup.fromJson(json).effectiveMinSelect, 1,
          reason: 'required and minSelect are independent columns');
    });

    test('an unlimited group has no maximum', () {
      final json = jsonDecode(group) as Map<String, dynamic>;
      json['maxSelect'] = null;

      expect(ModifierGroup.fromJson(json).maxSelect, isNull);
    });
  });

  group('RestaurantConfig from GET /restaurant/config', () {
    test('reads the branch\'s pricing rules', () {
      // Verbatim from the seeded Gulberg outlet.
      final config = RestaurantConfig.fromJson(jsonDecode('''
        {
          "branchId": "e9ff122f-6adb-4d44-888a-81a10085c9ba",
          "serviceModel": "DINE_IN", "channels": ["DINE_IN","TAKEAWAY","DELIVERY"],
          "currency": "PKR", "defaultTaxBp": 1600, "serviceChargeBp": 0,
          "buffetPrice": null, "autoFireKitchen": true, "tipEnabled": true,
          "roundingEnabled": true, "timezone": "Asia/Karachi"
        }'''));

      expect(config.currency, 'PKR');
      expect(config.defaultTaxBp, 1600);
      expect(config.roundingEnabled, isTrue);
      expect(config.autoFireKitchen, isTrue);
    });

    test('an unconfigured branch charges no tax, exactly as the server does',
        () {
      expect(RestaurantConfig.fallback.defaultTaxBp, 0,
          reason: 'charging tax the server will not charge puts the till out');
    });
  });

  group('MenuCategory', () {
    test('reads a seeded category', () {
      final category = MenuCategory.fromJson(jsonDecode('''
        {"id": "94faee03-bf1a-4102-ae94-13599df3cd50", "name": "BBQ & Grill",
         "parentId": null, "sortOrder": 0, "active": true, "imageKey": null,
         "itemCount": 2}'''));

      expect(category.name, 'BBQ & Grill');
      expect(category.itemCount, 2);
      expect(category.parentId, isNull);
    });
  });
}
