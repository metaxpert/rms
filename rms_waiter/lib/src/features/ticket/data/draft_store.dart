import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rms_core/rms_core.dart';

/// On-device storage for ticket drafts.
///
/// A waiter who takes an order at a table and then puts the tablet down — or
/// drops it, or watches it reboot — must find the order still there. Drafts are
/// therefore written on every change rather than held only in memory.
///
/// Reads are synchronous because `SharedPreferences` is an in-memory map once
/// loaded, which is what lets the floor screen mark tables with unsent orders
/// without an async gap.
class DraftStore {
  DraftStore(this._prefs);

  final SharedPreferences _prefs;

  static const _prefix = 'ticket_draft:';

  static String keyFor(String branchId, String tableId) =>
      '$_prefix$branchId:$tableId';

  /// The draft for a table, or null when there is none, it is unreadable, or it
  /// is too old to be this service's. A stale or unreadable draft is deleted on
  /// the spot: leaving it would offer it again at the next open.
  TicketDraft? read({
    required String branchId,
    required String tableId,
    required DateTime now,
  }) {
    final raw = _prefs.getString(keyFor(branchId, tableId));
    if (raw == null) return null;

    TicketDraft? draft;
    try {
      final json = jsonDecode(raw);
      draft = json is Map<String, dynamic> ? TicketDraft.fromJson(json) : null;
    } on FormatException {
      draft = null;
    }

    if (draft == null || draft.isStaleAt(now)) {
      _prefs.remove(keyFor(branchId, tableId));
      return null;
    }
    return draft;
  }

  Future<void> write(TicketDraft draft) {
    // An emptied ticket is a deleted ticket — otherwise the table would keep
    // its "unsent order" marker after the waiter cleared it.
    if (draft.isEmpty) return clear(draft.branchId, draft.tableId);
    return _prefs.setString(
      keyFor(draft.branchId, draft.tableId),
      jsonEncode(draft.toJson()),
    );
  }

  Future<void> clear(String branchId, String tableId) =>
      _prefs.remove(keyFor(branchId, tableId));

  /// Tables in this outlet that hold an unsent draft, for the floor plan.
  ///
  /// Stale drafts are excluded but not deleted here — a read-only call that
  /// mutates storage as a side effect would be a poor neighbour; [read] cleans
  /// them up when the table is next opened.
  Set<String> tablesWithDrafts({
    required String branchId,
    required DateTime now,
  }) {
    final prefix = '$_prefix$branchId:';
    final ids = <String>{};
    for (final key in _prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final raw = _prefs.getString(key);
      if (raw == null) continue;
      try {
        final json = jsonDecode(raw);
        final draft =
            json is Map<String, dynamic> ? TicketDraft.fromJson(json) : null;
        if (draft != null && draft.isNotEmpty && !draft.isStaleAt(now)) {
          ids.add(draft.tableId);
        }
      } on FormatException {
        continue;
      }
    }
    return ids;
  }
}

final draftStoreProvider = Provider<DraftStore>(
  (ref) => DraftStore(ref.watch(sharedPreferencesProvider)),
);

/// Tables with an unsent draft, watched by the floor plan. Invalidated by the
/// ticket controller whenever a draft is written or cleared.
final tablesWithDraftsProvider = Provider<Set<String>>((ref) {
  final branchId = ref.watch(sessionProvider).branchId;
  if (branchId == null) return const {};
  return ref.watch(draftStoreProvider).tablesWithDrafts(
        branchId: branchId,
        now: DateTime.now(),
      );
});
