import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rms_core/rms_core.dart';
import '../data/draft_store.dart';

/// Which table's ticket a controller is for.
///
/// The code travels with the id so a restored draft can name its table without
/// a floor fetch, but only the ids take part in equality — a table renamed
/// mid-service is still the same table, and re-keying the family on a rename
/// would silently abandon the ticket on it.
@immutable
class TicketRef {
  const TicketRef({
    required this.branchId,
    required this.tableId,
    required this.tableCode,
  });

  final String branchId;
  final String tableId;
  final String tableCode;

  @override
  bool operator ==(Object other) =>
      other is TicketRef &&
      other.branchId == branchId &&
      other.tableId == tableId;

  @override
  int get hashCode => Object.hash(branchId, tableId);
}

/// The draft ticket for one table.
///
/// Every change is written to disk immediately. The alternative — saving on
/// screen exit — loses the order exactly when it hurts most: the app being
/// killed in the background while the waiter is at another table.
class TicketController extends FamilyNotifier<TicketDraft, TicketRef> {
  @override
  TicketDraft build(TicketRef ref) {
    final store = this.ref.watch(draftStoreProvider);
    final now = DateTime.now();

    final restored = store.read(
      branchId: ref.branchId,
      tableId: ref.tableId,
      now: now,
    );
    _restoredAt = restored?.updatedAt;
    return restored ??
        TicketDraft.empty(
          branchId: ref.branchId,
          tableId: ref.tableId,
          tableCode: ref.tableCode,
          now: now,
        );
  }

  /// When the ticket now on screen was last edited, if it came off disk rather
  /// than being started here. The screen says so: a waiter arriving at a table
  /// needs to know these lines were entered earlier, possibly by someone else.
  DateTime? get restoredAt => _restoredAt;
  DateTime? _restoredAt;

  void add(DraftLine line) => _update((draft) => draft.add(line, now: _now));

  void setQty(int index, int qty) =>
      _update((draft) => draft.setQty(index, qty, now: _now));

  void removeAt(int index) => _update((draft) => draft.removeAt(index, now: _now));

  void setGuestCount(int? guests) =>
      _update((draft) => draft.withGuestCount(guests, now: _now));

  void clear() => _update((draft) => draft.clearLines(now: _now));

  DateTime get _now => DateTime.now();

  void _update(TicketDraft Function(TicketDraft) change) {
    state = change(state);
    _persist();
  }

  void _persist() {
    // Not awaited: a preferences write is a memory update plus a background
    // flush, and blocking the tap that added a dish on disk I/O would make the
    // menu feel slow for no benefit.
    ref.read(draftStoreProvider).write(state);
    // The floor plan's "unsent order" markers are derived from storage.
    ref.invalidate(tablesWithDraftsProvider);
  }
}

final ticketControllerProvider =
    NotifierProvider.family<TicketController, TicketDraft, TicketRef>(
  TicketController.new,
);
