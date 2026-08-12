import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';

import 'pricing_fixtures.dart';

/// The draft ticket exists to predict what the server will charge. These tests
/// hold it to that: the arithmetic is checked line-by-line and total-by-total
/// against numbers produced by the backend's own formulas (see
/// [pricingFixturesJson]), not against expectations written by hand here.
void main() {
  const pkr = 'PKR';
  final now = DateTime(2026, 8, 13, 19, 30);

  MenuItem item({
    String id = 'item-1',
    String name = 'Chicken Karahi',
    int priceMinor = 132000,
    int? taxBp = 1600,
    bool available = true,
    String status = 'ACTIVE',
  }) =>
      MenuItem(
        id: id,
        name: name,
        price: Money(priceMinor, pkr),
        available: available,
        status: status,
        isCombo: false,
        prepMinutes: 10,
        taxBp: taxBp,
      );

  TicketDraft draftWith(List<DraftLine> lines) => TicketDraft(
        branchId: 'branch-1',
        tableId: 'table-1',
        tableCode: 'D1',
        lines: lines,
        updatedAt: now,
      );

  group('pricing matches the backend, case for case', () {
    final cases = (jsonDecode(pricingFixturesJson) as List)
        .cast<Map<String, dynamic>>();

    test('every fixture agrees to the paisa', () {
      expect(cases, hasLength(110));

      for (final c in cases) {
        final label = c['label'] as String;
        final config = RestaurantConfig(
          currency: pkr,
          defaultTaxBp: 0,
          serviceChargeBp: (c['serviceChargeBp'] as num).toInt(),
          roundingEnabled: c['roundingEnabled'] as bool,
          tipEnabled: true,
          autoFireKitchen: true,
        );

        final lines = <DraftLine>[];
        for (final raw in (c['lines'] as List).cast<Map<String, dynamic>>()) {
          final modifierUnit = (raw['modifierUnitMinor'] as num).toInt();
          lines.add(DraftLine(
            itemId: 'item-${lines.length}',
            name: 'Item ${lines.length}',
            unitPrice: Money((raw['unitPriceMinor'] as num).toInt(), pkr),
            taxBp: (raw['taxBp'] as num).toInt(),
            qty: (raw['qty'] as num).toInt(),
            modifiers: modifierUnit == 0
                ? const []
                : [
                    DraftModifier(
                      modifierId: 'mod-${lines.length}',
                      name: 'Modifier',
                      priceDelta: Money(modifierUnit, pkr),
                    ),
                  ],
          ));
        }

        final expectedLineTax = (c['lineTax'] as List).cast<num>();
        final expectedLineTotal = (c['lineTotal'] as List).cast<num>();
        for (var i = 0; i < lines.length; i++) {
          expect(lines[i].tax.minor, expectedLineTax[i].toInt(),
              reason: '$label — line $i tax');
          expect(lines[i].total.minor, expectedLineTotal[i].toInt(),
              reason: '$label — line $i total');
        }

        final expected = c['totals'] as Map<String, dynamic>;
        final totals = draftWith(lines).totals(config);
        expect(totals.subtotal.minor, (expected['subtotal'] as num).toInt(),
            reason: '$label — subtotal');
        expect(totals.tax.minor, (expected['tax'] as num).toInt(),
            reason: '$label — tax');
        expect(totals.serviceCharge.minor,
            (expected['serviceCharge'] as num).toInt(),
            reason: '$label — service charge');
        expect(totals.rounding.minor, (expected['rounding'] as num).toInt(),
            reason: '$label — rounding');
        expect(totals.total.minor, (expected['total'] as num).toInt(),
            reason: '$label — total');
      }
    });
  });

  group('tax rounding', () {
    test('line tax truncates, where half-up would over-charge', () {
      // 313 paisa at 16% is 50.08 → 50 either way; 1 paisa at 50% is exactly
      // 0.5, where the two rules part company. The server floors.
      final line = DraftLine(
        itemId: 'i',
        name: 'n',
        unitPrice: const Money(1, pkr),
        taxBp: 5000,
        qty: 1,
      );
      expect(line.tax.minor, 0);
      expect(const Money(1, pkr).applyBp(5000).minor, 1,
          reason: 'applyBp is half-up and must NOT be used for line tax');
    });

    test('rupee rounding follows JavaScript, half toward +∞', () {
      expect(const Money(12350).roundedToNearest(100).minor, 12400);
      expect(const Money(12349).roundedToNearest(100).minor, 12300);
      // Math.round(-0.5) is -0 in JS, not -1.
      expect(const Money(-50).roundedToNearest(100).minor, 0);
      expect(const Money(-51).roundedToNearest(100).minor, -100);
    });
  });

  group('building a ticket', () {
    const config = RestaurantConfig(
      currency: pkr,
      defaultTaxBp: 1600,
      serviceChargeBp: 0,
      roundingEnabled: true,
      tipEnabled: true,
      autoFireKitchen: true,
    );

    test('an item with no tax override inherits the branch default', () {
      final line = DraftLine.fromMenuItem(item(taxBp: null), config: config);
      expect(line.taxBp, 1600,
          reason: 'a null taxBp means "branch default", never zero-rated');
    });

    test('an explicit zero rate is honoured over the branch default', () {
      final line = DraftLine.fromMenuItem(item(taxBp: 0), config: config);
      expect(line.taxBp, 0);
      expect(line.tax.minor, 0);
    });

    test('tapping the same dish twice makes one line of two', () {
      final naan = item(id: 'naan', name: 'Garlic Naan', priceMinor: 12000);
      var draft = draftWith(const []);
      draft = draft.add(DraftLine.fromMenuItem(naan, config: config), now: now);
      draft = draft.add(DraftLine.fromMenuItem(naan, config: config), now: now);

      expect(draft.lines, hasLength(1));
      expect(draft.lines.single.qty, 2);
      expect(draft.itemCount, 2);
    });

    test('the same dish with different notes stays a separate line', () {
      final naan = item(id: 'naan', name: 'Garlic Naan', priceMinor: 12000);
      var draft = draftWith(const []);
      draft = draft.add(DraftLine.fromMenuItem(naan, config: config), now: now);
      draft = draft.add(
        DraftLine.fromMenuItem(naan, config: config, kitchenNotes: 'no butter'),
        now: now,
      );

      expect(draft.lines, hasLength(2),
          reason: 'the kitchen must not be told to cook both the same way');
    });

    test('different modifier choices stay separate lines', () {
      final tikka = item(id: 'tikka', priceMinor: 86000);
      const spicy = DraftModifier(
        modifierId: 'm-spicy',
        name: 'Extra spicy',
        priceDelta: Money(0, pkr),
      );
      var draft = draftWith(const []);
      draft = draft.add(DraftLine.fromMenuItem(tikka, config: config), now: now);
      draft = draft.add(
        DraftLine.fromMenuItem(tikka, config: config, modifiers: const [spicy]),
        now: now,
      );

      expect(draft.lines, hasLength(2));
    });

    test('modifier order does not split an otherwise identical line', () {
      const a = DraftModifier(
          modifierId: 'a', name: 'A', priceDelta: Money(1000, pkr));
      const b = DraftModifier(
          modifierId: 'b', name: 'B', priceDelta: Money(2000, pkr));
      final tikka = item(id: 'tikka', priceMinor: 86000);

      var draft = draftWith(const []);
      draft = draft.add(
          DraftLine.fromMenuItem(tikka, config: config, modifiers: const [a, b]),
          now: now);
      draft = draft.add(
          DraftLine.fromMenuItem(tikka, config: config, modifiers: const [b, a]),
          now: now);

      expect(draft.lines, hasLength(1));
      expect(draft.lines.single.qty, 2);
    });

    test('setting a quantity to zero removes the line', () {
      var draft = draftWith(const []);
      draft = draft.add(DraftLine.fromMenuItem(item(), config: config, qty: 3),
          now: now);
      draft = draft.setQty(0, 0, now: now);

      expect(draft.isEmpty, isTrue);
    });

    test('modifiers are charged per unit, not per line', () {
      const cheese = DraftModifier(
        modifierId: 'm-cheese',
        name: 'Extra cheese',
        priceDelta: Money(2500, pkr),
      );
      final line = DraftLine.fromMenuItem(
        item(priceMinor: 86000),
        config: config,
        qty: 4,
        modifiers: const [cheese],
      );

      expect(line.pricedUnit.minor, 88500);
      expect(line.taxable.minor, 354000);
    });

    test('an empty draft totals to zero in the branch currency', () {
      final totals = draftWith(const []).totals(config);
      expect(totals.total, Money.zero);
      expect(totals.total.currency, pkr);
    });
  });

  group('persistence', () {
    test('a draft survives a round trip through JSON', () {
      const config = RestaurantConfig(
        currency: pkr,
        defaultTaxBp: 1600,
        serviceChargeBp: 250,
        roundingEnabled: true,
        tipEnabled: true,
        autoFireKitchen: true,
      );
      var draft = draftWith(const []).withGuestCount(4, now: now);
      draft = draft.add(
        DraftLine.fromMenuItem(
          item(),
          config: config,
          qty: 2,
          kitchenNotes: 'no chilli',
          course: 2,
          modifiers: const [
            DraftModifier(
              modifierId: 'm1',
              name: 'Extra raita',
              priceDelta: Money(3000, pkr),
              qty: 2,
            ),
          ],
        ),
        now: now,
      );

      final restored =
          TicketDraft.fromJson(jsonDecode(jsonEncode(draft.toJson())));

      expect(restored, isNotNull);
      expect(restored!.tableCode, 'D1');
      expect(restored.guestCount, 4);
      expect(restored.lines, hasLength(1));
      expect(restored.lines.single.kitchenNotes, 'no chilli');
      expect(restored.lines.single.course, 2);
      expect(restored.lines.single.modifiers.single.qty, 2);
      expect(restored.totals(config).total, draft.totals(config).total,
          reason: 'a restored ticket must quote the same bill');
    });

    test('a draft written by a newer build is refused, not half-read', () {
      final json = draftWith(const []).toJson()..['version'] = 99;
      expect(TicketDraft.fromJson(json), isNull);
    });

    test('malformed storage is refused', () {
      expect(TicketDraft.fromJson({'version': 1, 'tableId': 42}), isNull);
      expect(
        TicketDraft.fromJson({
          'version': 1,
          'branchId': 'b',
          'tableId': 't',
          'updatedAt': 'not-a-date',
        }),
        isNull,
      );
    });

    test('yesterday\'s draft is stale, this hour\'s is not', () {
      final draft = draftWith(const []);
      expect(draft.isStaleAt(now.add(const Duration(hours: 2))), isFalse);
      expect(draft.isStaleAt(now.add(const Duration(hours: 13))), isTrue);
    });
  });

  group('the API payload', () {
    const config = RestaurantConfig(
      currency: pkr,
      defaultTaxBp: 1600,
      serviceChargeBp: 0,
      roundingEnabled: true,
      tipEnabled: true,
      autoFireKitchen: true,
    );

    test('sends only what OrderItemInputDto accepts', () {
      final line = DraftLine.fromMenuItem(
        item(),
        config: config,
        qty: 2,
        kitchenNotes: '  well done  ',
        modifiers: const [
          DraftModifier(
            modifierId: 'm1',
            name: 'Extra raita',
            priceDelta: Money(3000, pkr),
          ),
        ],
      );

      expect(line.toApiJson(), {
        'itemId': 'item-1',
        'qty': 2,
        'kitchenNotes': 'well done',
        'modifiers': [
          {'modifierId': 'm1', 'qty': 1},
        ],
      });
    });

    test('omits empty notes rather than sending blank kitchen instructions',
        () {
      final line =
          DraftLine.fromMenuItem(item(), config: config, kitchenNotes: '   ');
      expect(line.toApiJson().containsKey('kitchenNotes'), isFalse);
    });

    test('never sends a price — the server re-prices every line', () {
      final line = DraftLine.fromMenuItem(item(), config: config);
      expect(line.toApiJson().keys, isNot(contains('unitPriceMinor')));
      expect(line.toApiJson().keys, isNot(contains('taxBp')));
    });
  });
}
