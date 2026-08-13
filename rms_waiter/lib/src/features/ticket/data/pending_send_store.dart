import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rms_core/rms_core.dart';

/// How far a submission got.
///
/// Sending a ticket is four server calls — create, add items, place, confirm —
/// and the app can die between any two of them. Recording the boundary reached
/// is what lets the next attempt continue rather than start over and open a
/// second bill for the table.
enum SendStage {
  /// No order exists yet.
  creating,

  /// The order exists; its lines have not been accepted.
  addingItems,

  /// Lines are on the order; it is still DRAFT.
  placing,

  /// The order is PLACED; the kitchen has not been fired.
  confirming;

  static SendStage fromWire(String? value) => values.firstWhere(
        (stage) => stage.name == value,
        orElse: () => SendStage.creating,
      );
}

/// A submission in flight, persisted so that a crash, a kill, or a flat battery
/// mid-send cannot turn one round into two.
@immutable
class PendingSend {
  const PendingSend({
    required this.branchId,
    required this.tableId,
    required this.key,
    required this.stage,
    required this.items,
    required this.startedAt,
    this.orderId,
    this.guestCount,
  });

  final String branchId;
  final String tableId;

  /// Base idempotency key for this submission, minted once and reused by every
  /// attempt. Each step derives its own key from it via [keyFor], so the four
  /// calls never collide with each other while each stays stable across
  /// retries — including retries by a waiter, days of battery apart.
  final String key;

  final SendStage stage;

  /// The item payload, frozen at the moment the waiter tapped Send.
  ///
  /// Frozen rather than re-derived because the same idempotency key must carry
  /// the same body: re-encoding from a draft the waiter has since edited would
  /// turn a resume into a 422.
  final List<Map<String, dynamic>> items;

  final DateTime startedAt;

  /// Known once the order exists. Its presence is what stops a retry creating a
  /// second order.
  final String? orderId;

  final int? guestCount;

  int get itemCount => items.fold(
        0,
        (sum, item) => sum + ((item['qty'] as num?)?.toInt() ?? 0),
      );

  /// Per-step key. Distinct per step because the interceptor rejects the same
  /// key with a different body (422), and the four calls carry different bodies.
  String keyFor(SendStage stage) => '$key:${stage.name}';

  PendingSend copyWith({SendStage? stage, String? orderId}) => PendingSend(
        branchId: branchId,
        tableId: tableId,
        key: key,
        stage: stage ?? this.stage,
        items: items,
        startedAt: startedAt,
        orderId: orderId ?? this.orderId,
        guestCount: guestCount,
      );

  /// A submission older than this is not this service's.
  ///
  /// Twelve hours matches the draft's own lifetime. An order created by such a
  /// submission is not lost — it is on the floor screen like any other open
  /// bill; what is discarded is only this device's intent to keep pushing it.
  static const maxAge = Duration(hours: 12);

  bool isStaleAt(DateTime now) => now.difference(startedAt) > maxAge;

  static const schemaVersion = 1;

  Map<String, dynamic> toJson() => {
        'version': schemaVersion,
        'branchId': branchId,
        'tableId': tableId,
        'key': key,
        'stage': stage.name,
        'items': items,
        'startedAt': startedAt.toUtc().toIso8601String(),
        if (orderId != null) 'orderId': orderId,
        if (guestCount != null) 'guestCount': guestCount,
      };

  /// Returns null for anything this build cannot faithfully resume. Half a
  /// submission is worse than none: it would be retried against a key whose
  /// body we no longer know.
  static PendingSend? fromJson(Map<String, dynamic> json) {
    if ((json['version'] as num?)?.toInt() != schemaVersion) return null;
    final branchId = json['branchId'];
    final tableId = json['tableId'];
    final key = json['key'];
    final startedAt = DateTime.tryParse((json['startedAt'] as String?) ?? '');
    if (branchId is! String ||
        tableId is! String ||
        key is! String ||
        startedAt == null) {
      return null;
    }
    return PendingSend(
      branchId: branchId,
      tableId: tableId,
      key: key,
      stage: SendStage.fromWire(json['stage'] as String?),
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false),
      startedAt: startedAt.toLocal(),
      orderId: json['orderId'] as String?,
      guestCount: (json['guestCount'] as num?)?.toInt(),
    );
  }

  /// A fresh submission for a draft.
  factory PendingSend.forDraft(
    TicketDraft draft, {
    required DateTime now,
    required String key,
  }) =>
      PendingSend(
        branchId: draft.branchId,
        tableId: draft.tableId,
        key: key,
        stage: SendStage.creating,
        items: draft.lines.map((l) => l.toApiJson()).toList(growable: false),
        startedAt: now,
        guestCount: draft.guestCount,
      );
}

class PendingSendStore {
  PendingSendStore(this._prefs);

  final SharedPreferences _prefs;

  static const _prefix = 'pending_send:';

  static String keyFor(String branchId, String tableId) =>
      '$_prefix$branchId:$tableId';

  PendingSend? read({
    required String branchId,
    required String tableId,
    required DateTime now,
  }) {
    final raw = _prefs.getString(keyFor(branchId, tableId));
    if (raw == null) return null;

    PendingSend? pending;
    try {
      final json = jsonDecode(raw);
      pending = json is Map<String, dynamic> ? PendingSend.fromJson(json) : null;
    } on FormatException {
      pending = null;
    }

    if (pending == null || pending.isStaleAt(now)) {
      _prefs.remove(keyFor(branchId, tableId));
      return null;
    }
    return pending;
  }

  Future<void> write(PendingSend pending) => _prefs.setString(
        keyFor(pending.branchId, pending.tableId),
        jsonEncode(pending.toJson()),
      );

  Future<void> clear(String branchId, String tableId) =>
      _prefs.remove(keyFor(branchId, tableId));

  /// Every unfinished submission in this outlet.
  ///
  /// Ordered oldest first, so a queue drained after a wifi drop fires the
  /// kitchen in the order the tables were actually served.
  List<PendingSend> all({required String branchId, required DateTime now}) {
    final prefix = '$_prefix$branchId:';
    final found = <PendingSend>[];
    for (final key in _prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final raw = _prefs.getString(key);
      if (raw == null) continue;
      try {
        final json = jsonDecode(raw);
        final pending =
            json is Map<String, dynamic> ? PendingSend.fromJson(json) : null;
        if (pending != null && !pending.isStaleAt(now)) found.add(pending);
      } on FormatException {
        continue;
      }
    }
    return found..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  }

  /// Tables in this outlet holding an unfinished submission, for the floor plan.
  /// These are more urgent than an unsent draft: an order may already exist
  /// server-side with nothing behind it.
  Set<String> tablesWithPendingSends({
    required String branchId,
    required DateTime now,
  }) =>
      all(branchId: branchId, now: now).map((p) => p.tableId).toSet();

  /// A key with enough entropy that two tablets sending at the same second
  /// cannot collide. Collision would make one waiter's send replay the other's
  /// response — the same failure mode as no key at all, but harder to see.
  static String newKey([Random? random]) {
    final rng = random ?? Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}

final pendingSendStoreProvider = Provider<PendingSendStore>(
  (ref) => PendingSendStore(ref.watch(sharedPreferencesProvider)),
);

/// Tables with a submission that did not finish. Invalidated by the send
/// controller whenever a submission starts, advances or resolves.
final tablesWithPendingSendsProvider = Provider<Set<String>>((ref) {
  final branchId = ref.watch(sessionProvider).branchId;
  if (branchId == null) return const {};
  return ref.watch(pendingSendStoreProvider).tablesWithPendingSends(
        branchId: branchId,
        now: DateTime.now(),
      );
});
