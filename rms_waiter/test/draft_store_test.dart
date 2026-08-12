import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';
import 'package:rms_waiter/src/features/ticket/data/draft_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Drafts are the one thing in this app that only exists on the device: nothing
/// on the server knows about an order that has not been sent. These tests hold
/// the store to never losing one silently — and to never resurrecting one that
/// belongs to a different service or a different outlet.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 8, 13, 20, 15);

  Future<DraftStore> store([Map<String, Object> initial = const {}]) async {
    SharedPreferences.setMockInitialValues(initial);
    return DraftStore(await SharedPreferences.getInstance());
  }

  TicketDraft draft({
    String branchId = 'branch-1',
    String tableId = 'table-1',
    String tableCode = 'D1',
    DateTime? updatedAt,
    int lines = 1,
  }) =>
      TicketDraft(
        branchId: branchId,
        tableId: tableId,
        tableCode: tableCode,
        updatedAt: updatedAt ?? now,
        lines: [
          for (var i = 0; i < lines; i++)
            DraftLine(
              itemId: 'item-$i',
              name: 'Chicken Karahi',
              unitPrice: const Money(132000),
              taxBp: 1600,
              qty: 1,
            ),
        ],
      );

  test('a written draft comes back', () async {
    final subject = await store();
    await subject.write(draft());

    final restored =
        subject.read(branchId: 'branch-1', tableId: 'table-1', now: now);

    expect(restored, isNotNull);
    expect(restored!.lines, hasLength(1));
    expect(restored.tableCode, 'D1');
  });

  test('another outlet\'s draft is not offered at this one', () async {
    final subject = await store();
    await subject.write(draft(branchId: 'branch-2'));

    expect(
      subject.read(branchId: 'branch-1', tableId: 'table-1', now: now),
      isNull,
      reason: 'the same table number exists at every outlet',
    );
  });

  test('a draft from a previous service is dropped, not offered', () async {
    final subject = await store();
    await subject.write(draft(updatedAt: now.subtract(const Duration(hours: 20))));

    expect(
      subject.read(branchId: 'branch-1', tableId: 'table-1', now: now),
      isNull,
      reason: 'yesterday\'s order must not be fired at today\'s guests',
    );
    expect(
      subject.tablesWithDrafts(branchId: 'branch-1', now: now),
      isEmpty,
      reason: 'and it must not mark the table on the floor either',
    );
  });

  test('a stale draft is deleted on read, not left to reappear', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final subject = DraftStore(prefs);
    await subject.write(draft(updatedAt: now.subtract(const Duration(days: 2))));

    subject.read(branchId: 'branch-1', tableId: 'table-1', now: now);

    expect(prefs.getString(DraftStore.keyFor('branch-1', 'table-1')), isNull);
  });

  test('corrupt storage is discarded rather than crashing the ticket', () async {
    final subject = await store({
      DraftStore.keyFor('branch-1', 'table-1'): 'not json at all',
    });

    expect(
      subject.read(branchId: 'branch-1', tableId: 'table-1', now: now),
      isNull,
    );
  });

  test('a draft from a newer schema is discarded', () async {
    final future = draft().toJson()..['version'] = 99;
    final subject = await store({
      DraftStore.keyFor('branch-1', 'table-1'): jsonEncode(future),
    });

    expect(
      subject.read(branchId: 'branch-1', tableId: 'table-1', now: now),
      isNull,
    );
  });

  test('emptying a ticket deletes it rather than storing an empty one',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final subject = DraftStore(prefs);

    await subject.write(draft());
    await subject.write(draft(lines: 0));

    expect(prefs.getString(DraftStore.keyFor('branch-1', 'table-1')), isNull,
        reason: 'an emptied ticket must clear the table\'s floor marker');
  });

  test('the floor learns which tables hold unsent orders', () async {
    final subject = await store();
    await subject.write(draft(tableId: 'table-1'));
    await subject.write(draft(tableId: 'table-7', tableCode: 'D7'));
    await subject.write(draft(tableId: 'table-9', branchId: 'branch-2'));

    expect(
      subject.tablesWithDrafts(branchId: 'branch-1', now: now),
      {'table-1', 'table-7'},
    );
  });
}
