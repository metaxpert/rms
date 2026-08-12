import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rms_core/rms_core.dart';

/// What a customer has chosen, before any of it reaches the restaurant.
///
/// Prices are computed with the same arithmetic the waiter's ticket uses
/// (`computeDraftTotals`), because a guest quoted one figure in this app and
/// charged another at the counter has been misled — and the two screens must
/// not be allowed to drift.
///
/// **It is still only a prediction.** The backend re-prices every line when the
/// order is placed, and that price wins.
@immutable
class Cart {
  const Cart({
    required this.branchId,
    required this.lines,
    required this.updatedAt,
  });

  /// Which restaurant this basket is for. A basket built at one branch cannot
  /// be carried to another: the prices, the menu and the tax may all differ.
  final String branchId;

  final List<DraftLine> lines;
  final DateTime updatedAt;

  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;
  int get itemCount => lines.fold(0, (sum, l) => sum + l.qty);

  DraftTotals totals(RestaurantConfig config) =>
      computeDraftTotals(lines, config);

  static Cart empty(String branchId, DateTime now) =>
      Cart(branchId: branchId, lines: const [], updatedAt: now);

  Cart add(DraftLine line, DateTime now) {
    final index = lines.indexWhere((l) => l.signature == line.signature);
    final next = [...lines];
    if (index >= 0) {
      next[index] = next[index].copyWith(qty: next[index].qty + line.qty);
    } else {
      next.add(line);
    }
    return _with(next, now);
  }

  Cart setQty(int index, int qty, DateTime now) {
    if (index < 0 || index >= lines.length) return this;
    final next = [...lines];
    if (qty <= 0) {
      next.removeAt(index);
    } else {
      next[index] = next[index].copyWith(qty: qty);
    }
    return _with(next, now);
  }

  Cart clear(DateTime now) => _with(const [], now);

  Cart _with(List<DraftLine> next, DateTime now) => Cart(
        branchId: branchId,
        lines: List.unmodifiable(next),
        updatedAt: now,
      );

  /// A basket older than this is not this visit's. Longer than the waiter's
  /// twelve hours: a customer may well add something at lunchtime and order it
  /// that evening, and losing their choices would be worse than showing them a
  /// price that has since moved — which the server corrects anyway.
  static const maxAge = Duration(days: 2);

  bool isStaleAt(DateTime now) => now.difference(updatedAt) > maxAge;

  static const schemaVersion = 1;

  Map<String, dynamic> toJson() => {
        'version': schemaVersion,
        'branchId': branchId,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'lines': lines.map((l) => l.toJson()).toList(),
      };

  /// Null for anything this build cannot faithfully restore. A half-restored
  /// basket is worse than an empty one: the customer would not know what had
  /// been dropped.
  static Cart? fromJson(Map<String, dynamic> json) {
    if ((json['version'] as num?)?.toInt() != schemaVersion) return null;
    final branchId = json['branchId'];
    final updatedAt = DateTime.tryParse((json['updatedAt'] as String?) ?? '');
    if (branchId is! String || updatedAt == null) return null;
    try {
      return Cart(
        branchId: branchId,
        updatedAt: updatedAt.toLocal(),
        lines: List.unmodifiable(((json['lines'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(DraftLine.fromJson)
            .toList()),
      );
    } on TypeError {
      return null;
    }
  }
}

/// On-device basket storage, keyed by restaurant.
class CartStore {
  CartStore(this._prefs);

  final SharedPreferences _prefs;

  static String keyFor(String branchId) => 'cart:$branchId';

  Cart? read(String branchId, DateTime now) {
    final raw = _prefs.getString(keyFor(branchId));
    if (raw == null) return null;

    Cart? cart;
    try {
      final json = jsonDecode(raw);
      cart = json is Map<String, dynamic> ? Cart.fromJson(json) : null;
    } on FormatException {
      cart = null;
    }

    if (cart == null || cart.isStaleAt(now)) {
      _prefs.remove(keyFor(branchId));
      return null;
    }
    return cart;
  }

  Future<void> write(Cart cart) {
    if (cart.isEmpty) return _prefs.remove(keyFor(cart.branchId));
    return _prefs.setString(keyFor(cart.branchId), jsonEncode(cart.toJson()));
  }
}

final cartStoreProvider = Provider<CartStore>(
  (ref) => CartStore(ref.watch(sharedPreferencesProvider)),
);

/// The basket for the chosen restaurant.
///
/// Written to disk on every change rather than on leaving the screen: a phone
/// that rings, sleeps or dies mid-browse must not cost the customer their
/// choices.
class CartController extends Notifier<Cart> {
  @override
  Cart build() {
    final branchId = ref.watch(sessionProvider).branchId ?? '';
    final now = DateTime.now();
    return ref.watch(cartStoreProvider).read(branchId, now) ??
        Cart.empty(branchId, now);
  }

  void add(MenuItem item, RestaurantConfig config, {int qty = 1}) => _update(
        (cart) => cart.add(
          DraftLine.fromMenuItem(item, config: config, qty: qty),
          DateTime.now(),
        ),
      );

  void setQty(int index, int qty) =>
      _update((cart) => cart.setQty(index, qty, DateTime.now()));

  void clear() => _update((cart) => cart.clear(DateTime.now()));

  void _update(Cart Function(Cart) change) {
    state = change(state);
    // Not awaited: a preferences write is a memory update plus a background
    // flush, and blocking the tap that added a dish on disk I/O would make the
    // menu feel slow for nothing.
    ref.read(cartStoreProvider).write(state);
  }
}

final cartControllerProvider =
    NotifierProvider<CartController, Cart>(CartController.new);
